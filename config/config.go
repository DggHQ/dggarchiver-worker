package config

import (
	"encoding/json"
	"os"
	"strings"
	"time"

	log "github.com/DggHQ/dggarchiver-logger"
	dggarchivermodel "github.com/DggHQ/dggarchiver-model"
	"github.com/joho/godotenv"
	"github.com/nats-io/nats.go"
)

type Flags struct {
	Verbose bool
}

type NATSConfig struct {
	Host           string
	Topic          string
	NatsConnection *nats.Conn
}

type Config struct {
	Flags      Flags
	NATSConfig NATSConfig
	VOD        dggarchivermodel.YTVod
}

type Storage struct {
	UseS3     bool
	AccessKey string
	SecretKey string
	Endpoint  string
	VodPath   string
}

func (cfg *Config) loadDotEnv() {
	log.Debugf("Loading environment variables")
	godotenv.Load()

	// Flags
	verbose := strings.ToLower(os.Getenv("VERBOSE"))
	if verbose == "1" || verbose == "true" {
		cfg.Flags.Verbose = true
	}

	// NATS Host Name or IP
	cfg.NATSConfig.Host = os.Getenv("NATS_HOST")
	if cfg.NATSConfig.Host == "" {
		log.Fatalf("Please set the NATS_HOST environment variable and restart the app")
	}

	// NATS Topic Name
	cfg.NATSConfig.Topic = os.Getenv("NATS_TOPIC")
	if cfg.NATSConfig.Topic == "" {
		log.Fatalf("Please set the NATS_TOPIC environment variable and restart the app")
	}

	// VOD
	vod := os.Getenv("LIVESTREAM_INFO")
	if vod == "" {
		log.Fatalf("Please set the LIVESTREAM_INFO environment variable and restart the app")
	}
	err := json.Unmarshal([]byte(vod), &cfg.VOD)
	if err != nil {
		log.Fatalf("Error unmarshalling the VOD info: %s", err)
	}

	log.Debugf("Environment variables loaded successfully")
}

func (cfg *Config) loadNats() {
	// Connect to NATS server
	nc, err := nats.Connect(cfg.NATSConfig.Host, nil, nats.PingInterval(20*time.Second), nats.MaxPingsOutstanding(5))
	if err != nil {
		log.Fatalf("Wasn't able to declare the AMQP queue: %s", err)
		log.Fatalf("Could not connect to NATS server: %s", err)
	}
	log.Infof("Successfully connected to NATS server: %s", cfg.NATSConfig.Host)
	cfg.NATSConfig.NatsConnection = nc
}

func (cfg *Config) Initialize() {
	cfg.loadDotEnv()
	cfg.loadNats()
}
