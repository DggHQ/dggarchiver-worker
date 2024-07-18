package main

import (
	"encoding/json"
	"fmt"
	"os"
	"time"

	log "github.com/DggHQ/dggarchiver-logger"
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

func main() {
	cfg := config.Config{}
	cfg.Initialize()

	if cfg.Flags.Verbose {
		log.SetLevel(log.DebugLevel)
	}

	var path string

	if len(os.Args) > 1 {
		path = os.Args[1]
	} else {
		log.Fatalf("No path to video provided")
	}

	cfg.VOD.Path = path

	log.Infof("Downloaded VOD with ID %s: %s", cfg.VOD.VID, cfg.VOD)

	videoInfo := ffmpeg.GetVideoInfo(path)

	cfg.VOD.Duration = int(videoInfo.Format.DurationSeconds)

	log.Infof("Added duration to VOD with ID %s: %ss", cfg.VOD.VID, cfg.VOD.Duration)

	cfg.VOD.ThumbnailPath = ffmpeg.SaveFrameAsThumbnail(path, (cfg.VOD.Duration)/2, cfg.VOD.Thumbnail)

	bytes, err := json.Marshal(cfg.VOD)
	if err != nil {
		log.Fatalf("Couldn't marshal VOD with ID %s into a JSON object: %v", cfg.VOD.VID, err)
	}

	if err := cfg.NATSConfig.NatsConnection.Publish(fmt.Sprintf("%s.upload", cfg.NATSConfig.Topic), bytes); err != nil {
		log.Errorf("Wasn't able to send message with VOD with ID %s: %v", cfg.VOD.VID, err)
	}
	cfg.NATSConfig.NatsConnection.Close()

	fmt.Println(string(bytes))
}
