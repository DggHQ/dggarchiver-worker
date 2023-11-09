# downloader versions
# https://github.com/Kethsar/ytarchive/releases/latest
ARG YTARCHIVE_VERSION='dev'
# https://github.com/yt-dlp/yt-dlp/releases/latest
ARG YTDLP_VERSION='2023.07.06'
# https://github.com/nilaoda/N_m3u8DL-RE/releases/latest
ARG M3U8DL_VERSION='v0.2.0-beta'

# building the main executable
FROM golang:alpine as builder-base
LABEL builder=true multistage_tag="dggarchiver-worker-builder"
RUN apk add --no-cache upx ca-certificates tzdata

FROM builder-base as builder-modules
LABEL builder=true multistage_tag="dggarchiver-worker-builder"
ARG TARGETARCH
WORKDIR /build
COPY go.mod .
COPY go.sum .
RUN go mod download
RUN go mod verify

FROM builder-modules as builder
LABEL builder=true multistage_tag="dggarchiver-worker-builder"
ARG TARGETARCH
WORKDIR /build
COPY main.go .
COPY ./config ./config
COPY ./ffmpeg ./ffmpeg
COPY ./util ./util
RUN CGO_ENABLED=0 GOOS=linux GOARCH=${TARGETARCH} go build -tags netgo -trimpath -ldflags '-s -w -extldflags="-static"' -v -o worker
RUN upx --best --lzma worker

# building ytarchive
FROM golang:alpine as builder-ytarchive
LABEL builder=true multistage_tag="dggarchiver-worker-builder-ytarchive"
ARG TARGETARCH
ARG YTARCHIVE_VERSION
WORKDIR /build
RUN CGO_ENABLED=0 GOOS=linux GOARCH=${TARGETARCH} go install github.com/Kethsar/ytarchive@${YTARCHIVE_VERSION}

# building yt-dlp
FROM python:alpine3.17 as builder-ytdlp
LABEL builder=true multistage_tag="dggarchiver-worker-builder-ytdlp"
ARG YTDLP_VERSION
WORKDIR /build
RUN apk add --no-cache git ffmpeg binutils
RUN git clone https://github.com/yt-dlp/yt-dlp.git --single-branch --branch ${YTDLP_VERSION} .
RUN python3 -m pip install -U pyinstaller -r requirements.txt
RUN python3 devscripts/make_lazy_extractors.py
RUN python3 pyinst.py -n yt-dlp

# building N_m3u8DL-RE
FROM mcr.microsoft.com/dotnet-buildtools/prereqs:alpine-3.17 as builder-dotnet-amd64
LABEL builder=true multistage_tag="dggarchiver-worker-builder-m3u8dl"
RUN apk add --no-cache upx

FROM mcr.microsoft.com/dotnet-buildtools/prereqs:ubuntu-22.04-cross-arm64-alpine as builder-dotnet-arm64
LABEL builder=true multistage_tag="dggarchiver-worker-builder-m3u8dl"
RUN apt-get update && apt-get install -y upx

FROM builder-dotnet-${TARGETARCH} as builder-m3u8dl
LABEL builder=true multistage_tag="dggarchiver-worker-builder-m3u8dl"
ARG TARGETARCH
ARG M3U8DL_VERSION
WORKDIR /build
COPY --chmod=0755 ./scripts/build-dotnet.sh .
RUN wget https://dot.net/v1/dotnet-install.sh -O dotnet-install.sh
RUN chmod +x ./dotnet-install.sh
RUN ./dotnet-install.sh --channel 8.0
RUN ./build-dotnet.sh

# main image
FROM alpine:3.17 as base
RUN apk add --no-cache ffmpeg icu

FROM base
WORKDIR /app
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=builder /build/worker /usr/bin/
COPY --chmod=0755 ./scripts/run-worker.sh /usr/bin/run-worker
COPY --from=builder-ytarchive /go/bin/ytarchive /usr/bin/
COPY --from=builder-ytdlp /build/dist/yt-dlp /usr/bin/
COPY --from=builder-m3u8dl /build/artifacts/N_m3u8DL-RE /usr/bin/
CMD ["run-worker"]