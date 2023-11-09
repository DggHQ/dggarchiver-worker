.PHONY: build docker

TAG := $(shell git rev-parse --abbrev-ref HEAD | sed 's/[^a-zA-Z0-9]/-/g')
GOFLAGS := -tags netgo

DEBUG ?= 1
ifeq ($(DEBUG), 1)
	LDFLAGS := '-extldflags="-static"'
else
	GOFLAGS += -trimpath
	LDFLAGS := '-s -w -extldflags="-static"'
endif

GOFLAGS += -ldflags ${LDFLAGS}

build:
	CGO_ENABLED=0 go build ${GOFLAGS} -v -o target/dggarchiver-worker

docker:
	docker build -t dgghq/dggarchiver-worker:${TAG} .