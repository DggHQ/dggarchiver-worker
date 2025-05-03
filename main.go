package main

import (
	"encoding/json"
	"fmt"
	"os"
	"time"

	log "github.com/DggHQ/dggarchiver-logger"
	dggarchivermodel "github.com/DggHQ/dggarchiver-model"
	"github.com/DggHQ/dggarchiver-worker/config"
	"github.com/DggHQ/dggarchiver-worker/ffmpeg"
)

func init() {
	loc, err := time.LoadLocation("UTC")
	if err != nil {
		log.Fatalf("%s", err)
	}
	time.Local = loc
}

func calculateEndTime(startTime string, duration int) (string, error) {
	parsed, err := time.Parse(time.RFC3339, startTime)
	if err != nil {
		return "", err
	}

	endTimeParsed := parsed.Add(time.Second * time.Duration(duration))
	return endTimeParsed.Format(time.RFC3339), nil
}

func main() {
	cfg := config.Config{}
	cfg.Initialize()

	if cfg.Flags.Verbose {
		log.SetLevel(log.DebugLevel)
	}

	var path string

	if len(os.Args) > 2 {
		path = os.Args[2]
	} else {
		log.Fatalf("No path to video provided")
	}

	vodBytes, err := os.ReadFile(os.Args[1])
	if err != nil {
		log.Fatalf("Error reading the VOD info: %s", err)
	}

	var vod dggarchivermodel.VOD
	err = json.Unmarshal([]byte(vodBytes), &vod)
	if err != nil {
		log.Fatalf("Error unmarshalling the VOD info: %s", err)
	}

	vod.Path = path

	log.Infof("Downloaded VOD with ID %s: %s", vod.VID, vod)

	videoInfo := ffmpeg.GetVideoInfo(path)

	vod.Duration = int(videoInfo.Format.DurationSeconds)

	log.Infof("Added duration to VOD with ID %s: %ds", vod.VID, vod.Duration)

	vod.ThumbnailPath = ffmpeg.SaveFrameAsThumbnail(path, (vod.Duration)/2, vod.Thumbnail)

	vod.EndTime, err = calculateEndTime(vod.StartTime, vod.Duration)
	if err != nil {
		log.Fatalf("Wasn't able to calculate end time for VOD with ID %s (dur: %d): %v", vod.VID, vod.Duration, err)
	}

	bytes, err := json.Marshal(vod)
	if err != nil {
		log.Fatalf("Couldn't marshal VOD with ID %s into a JSON object: %v", vod.VID, err)
	}

	fmt.Println(string(bytes))

	if err := cfg.NATSConfig.NatsConnection.Publish(fmt.Sprintf("%s.upload", cfg.NATSConfig.Topic), bytes); err != nil {
		log.Errorf("Wasn't able to send message with VOD with ID %s: %v", vod.VID, err)
	}
	cfg.NATSConfig.NatsConnection.Close()
}
