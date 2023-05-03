FROM golang:alpine as builder-go
LABEL builder=true multistage_tag="dggarchiver-worker-builder-go"
ARG TARGETARCH
ARG YTARCHIVE_VERSION='v0.3.2'
WORKDIR /app
COPY . .
RUN GOOS=linux GOARCH=${TARGETARCH} go install github.com/Kethsar/ytarchive@${YTARCHIVE_VERSION}
RUN GOOS=linux GOARCH=${TARGETARCH} go build -v

FROM mcr.microsoft.com/dotnet-buildtools/prereqs:alpine-3.17 as builder-dotnet-amd64
RUN apk add --no-cache upx

FROM mcr.microsoft.com/dotnet-buildtools/prereqs:ubuntu-22.04-cross-arm64-alpine as builder-dotnet-arm64
RUN apt-get update && apt-get install -y upx

FROM builder-dotnet-${TARGETARCH} as builder-dotnet
LABEL builder=true multistage_tag="dggarchiver-worker-builder-dotnet"
ARG TARGETARCH
ARG M3U8DL_VERSION='v0.1.6-beta'
WORKDIR /app
COPY ./build-dotnet.sh .
RUN wget https://dot.net/v1/dotnet-install.sh -O dotnet-install.sh
RUN chmod +x ./dotnet-install.sh
RUN ./dotnet-install.sh --channel 7.0
RUN chmod +x ./build-dotnet.sh
RUN ./build-dotnet.sh

FROM python:alpine3.17
WORKDIR /app
COPY --from=builder-go /app/dggarchiver-worker .
COPY --from=builder-go /app/run.sh .
COPY --from=builder-go /go/bin/ytarchive /usr/bin/
COPY --from=builder-dotnet /app/artifacts/N_m3u8DL-RE /usr/bin/
RUN apk add --no-cache bash ffmpeg icu
RUN pip install -U yt-dlp
RUN chmod +x ./run.sh
CMD ["./run.sh"]