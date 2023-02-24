package main

import (
	"encoding/json"
	"os"
	"time"

	log "github.com/DggHQ/dggarchiver-logger"
	"github.com/DggHQ/dggarchiver-worker/config"
	"github.com/DggHQ/dggarchiver-worker/ffmpeg"
	amqp "github.com/rabbitmq/amqp091-go"
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

	log.Infof("Downloaded VOD with ID %s: %s", cfg.VOD.ID, cfg.VOD)

	videoInfo := ffmpeg.GetVideoInfo(path)

	cfg.VOD.Duration = int(videoInfo.Format.DurationSeconds)

	log.Infof("Added duration to VOD with ID %s: %ss", cfg.VOD.ID, cfg.VOD.Duration)

	frameRate := ffmpeg.CalculateFramerate(videoInfo)

	cfg.VOD.ThumbnailPath = ffmpeg.SaveFrameAsThumbnail(path, (cfg.VOD.Duration*frameRate)/2, cfg.VOD.Thumbnail)

	bytes, err := json.Marshal(cfg.VOD)
	if err != nil {
		log.Fatalf("Couldn't marshal VOD with ID %s into a JSON object: %v", cfg.VOD.ID, err)
	}

	msg := amqp.Publishing{
		ContentType: "application/json",
		Body:        bytes,
	}

	err = cfg.AMQPConfig.Channel.PublishWithContext(
		cfg.AMQPConfig.Context,
		cfg.AMQPConfig.ExchangeName,
		cfg.AMQPConfig.QueueName,
		false,
		false,
		msg,
	)
	if err != nil {
		log.Errorf("Wasn't able to send message with VOD with ID %s: %v", cfg.VOD.ID, err)
	}
}
