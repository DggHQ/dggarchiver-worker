package config

import (
	"context"
	"encoding/json"
	"os"
	"strings"

	log "github.com/DggHQ/dggarchiver-logger"
	dggarchivermodel "github.com/DggHQ/dggarchiver-model"
	"github.com/joho/godotenv"
	amqp "github.com/rabbitmq/amqp091-go"
)

type Flags struct {
	Verbose bool
}

type AMQPConfig struct {
	URI          string
	ExchangeName string
	ExchangeType string
	QueueName    string
	Context      context.Context
	Channel      *amqp.Channel
	connection   *amqp.Connection
}

type Config struct {
	Flags      Flags
	AMQPConfig AMQPConfig
	VOD        dggarchivermodel.YTVod
}

func (cfg *Config) loadDotEnv() {
	log.Debugf("Loading environment variables")
	godotenv.Load()

	// Flags
	verbose := strings.ToLower(os.Getenv("VERBOSE"))
	if verbose == "1" || verbose == "true" {
		cfg.Flags.Verbose = true
	}

	// AMQP
	cfg.AMQPConfig.URI = os.Getenv("AMQP_URI")
	if cfg.AMQPConfig.URI == "" {
		log.Fatalf("Please set the AMQP_URI environment variable and restart the app")
	}
	cfg.AMQPConfig.ExchangeName = ""
	cfg.AMQPConfig.ExchangeType = "direct"
	cfg.AMQPConfig.QueueName = "worker"

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

func (cfg *Config) loadAMQP() {
	var err error

	cfg.AMQPConfig.Context = context.Background()

	cfg.AMQPConfig.connection, err = amqp.Dial(cfg.AMQPConfig.URI)
	if err != nil {
		log.Fatalf("Wasn't able to connect to the AMQP server: %s", err)
	}

	cfg.AMQPConfig.Channel, err = cfg.AMQPConfig.connection.Channel()
	if err != nil {
		log.Fatalf("Wasn't able to create the AMQP channel: %s", err)
	}

	_, err = cfg.AMQPConfig.Channel.QueueDeclare(
		cfg.AMQPConfig.QueueName, // queue name
		true,                     // durable
		false,                    // auto delete
		false,                    // exclusive
		false,                    // no wait
		nil,                      // arguments
	)
	if err != nil {
		log.Fatalf("Wasn't able to declare the AMQP queue: %s", err)
	}
}

func (cfg *Config) Initialize() {
	cfg.loadDotEnv()
	cfg.loadAMQP()
}
