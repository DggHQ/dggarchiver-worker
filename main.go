package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"time"

	log "github.com/DggHQ/dggarchiver-logger"
	"github.com/DggHQ/dggarchiver-worker/config"
	"github.com/DggHQ/dggarchiver-worker/ffmpeg"
)

var stor config.Storage

func init() {
	flag.StringVar(&stor.AccessKey, "s3AccessKey", "", "Sets the S3 Access Key (used when useS3 is true)")
	flag.StringVar(&stor.SecretKey, "s3SecretKey", "", "Sets the S3 Secret Key (used when useS3 is true)")
	flag.StringVar(&stor.Endpoint, "s3Endpoint", "", "Sets the S3 Endpoint (used when useS3 is true)")
	flag.StringVar(&stor.VodPath, "vodPath", "", "Sets the outputh path and file name for the vod file")
	flag.BoolVar(&stor.UseS3, "useS3", false, "Use S3 Backend for uploading vods to be used with the uploader")
	loc, err := time.LoadLocation("UTC")
	if err != nil {
		log.Fatalf("%s", err)
	}
	time.Local = loc
}

func main() {
	flag.Parse()
	cfg := config.Config{}
	cfg.Initialize()

	if cfg.Flags.Verbose {
		log.SetLevel(log.DebugLevel)
	}

	cfg.VOD.Path = stor.VodPath

	log.Infof("Downloaded VOD with ID %s: %s", cfg.VOD.ID, cfg.VOD)

	videoInfo := ffmpeg.GetVideoInfo(stor.VodPath)

	cfg.VOD.Duration = int(videoInfo.Format.DurationSeconds)

	log.Infof("Added duration to VOD with ID %s: %ss", cfg.VOD.ID, cfg.VOD.Duration)

	cfg.VOD.ThumbnailPath = ffmpeg.SaveFrameAsThumbnail(stor.VodPath, (cfg.VOD.Duration)/2, cfg.VOD.Thumbnail)

	bytes, err := json.Marshal(cfg.VOD)
	if err != nil {
		log.Fatalf("Couldn't marshal VOD with ID %s into a JSON object: %v", cfg.VOD.ID, err)
	}

	if err := cfg.NATSConfig.NatsConnection.Publish(fmt.Sprintf("%s.upload", cfg.NATSConfig.Topic), bytes); err != nil {
		log.Errorf("Wasn't able to send message with VOD with ID %s: %v", cfg.VOD.ID, err)
	}
	cfg.NATSConfig.NatsConnection.Close()
}
