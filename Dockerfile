# downloader versions
# https://github.com/Kethsar/ytarchive/releases/latest
ARG YTARCHIVE_VERSION='dev2'
# https://github.com/yt-dlp/yt-dlp/releases/latest
ARG YTDLP_VERSION='2026.02.04'
# https://github.com/nilaoda/N_m3u8DL-RE/releases/latest
ARG M3U8DL_VERSION='v0.5.1-beta'
# https://github.com/jim60105/bgutil-ytdlp-pot-provider-rs/releases/latest
ARG BGUTIL_VERSION='v0.6.1'

# building the main executable
FROM golang:alpine3.23 AS builder-base
LABEL builder=true multistage_tag="dggarchiver-worker-builder"
RUN apk add --no-cache upx ca-certificates tzdata

FROM builder-base AS builder-modules
LABEL builder=true multistage_tag="dggarchiver-worker-builder"
ARG TARGETARCH
WORKDIR /build
COPY go.mod .
COPY go.sum .
RUN go mod download
RUN go mod verify

FROM builder-modules AS builder
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
FROM golang:alpine3.23 AS builder-ytarchive
LABEL builder=true multistage_tag="dggarchiver-worker-builder-ytarchive"
ARG TARGETARCH
ARG YTARCHIVE_VERSION
WORKDIR /build
RUN CGO_ENABLED=0 GOOS=linux GOARCH=${TARGETARCH} go install github.com/vyneer/ytarchive@${YTARCHIVE_VERSION}

# downloading yt-dlp
FROM alpine:3.23 AS builder-ytdlp-amd64
LABEL builder=true multistage_tag="dggarchiver-worker-builder-ytdlp"
ARG YTDLP_VERSION
WORKDIR /build
RUN apk add --no-cache wget
RUN wget -O /usr/bin/yt-dlp https://github.com/yt-dlp/yt-dlp/releases/download/${YTDLP_VERSION}/yt-dlp_musllinux
RUN chmod +x /usr/bin/yt-dlp

FROM alpine:3.23 AS builder-ytdlp-arm64
LABEL builder=true multistage_tag="dggarchiver-worker-builder-ytdlp"
ARG YTDLP_VERSION
WORKDIR /build
RUN apk add --no-cache wget
RUN wget -O /usr/bin/yt-dlp https://github.com/yt-dlp/yt-dlp/releases/download/${YTDLP_VERSION}/yt-dlp_linux_aarch64
RUN chmod +x /usr/bin/yt-dlp

FROM builder-ytdlp-${TARGETARCH} AS builder-ytdlp
LABEL builder=true multistage_tag="dggarchiver-worker-builder-ytdlp"

# downloading N_m3u8DL-RE
FROM alpine:3.23 AS builder-dotnet-amd64
LABEL builder=true multistage_tag="dggarchiver-worker-builder-m3u8dl"
ARG M3U8DL_VERSION
RUN apk add --no-cache curl jq
RUN wget -O m3u8DL.tar.gz $(curl --silent 'https://api.github.com/repos/nilaoda/N_m3u8DL-RE/releases/latest' | jq -r --arg VERSION "N_m3u8DL-RE_${M3U8DL_VERSION}_linux-musl-x64" '.assets[] | select(.name | startswith($VERSION)) .browser_download_url')
RUN tar xzvf m3u8DL.tar.gz && mv N_m3u8DL-RE /usr/bin/N_m3u8DL-RE

FROM alpine:3.23 AS builder-dotnet-arm64
LABEL builder=true multistage_tag="dggarchiver-worker-builder-m3u8dl"
ARG M3U8DL_VERSION
RUN apk add --no-cache curl jq
RUN wget -O m3u8DL.tar.gz $(curl --silent 'https://api.github.com/repos/nilaoda/N_m3u8DL-RE/releases/latest' | jq -r --arg VERSION "N_m3u8DL-RE_${M3U8DL_VERSION}_linux-arm64" '.assets[] | select(.name | startswith($VERSION)) .browser_download_url')
RUN tar xzvf m3u8DL.tar.gz && mv N_m3u8DL-RE /usr/bin/N_m3u8DL-RE

FROM builder-dotnet-${TARGETARCH} AS builder-m3u8dl
LABEL builder=true multistage_tag="dggarchiver-worker-builder-m3u8dl"

# building bgutil-pot
FROM ghcr.io/jim60105/bgutil-pot:${BGUTIL_VERSION} AS builder-bgutil-pot-amd64
LABEL builder=true multistage_tag="dggarchiver-worker-builder-bgutil-pot"

FROM rust:slim-trixie AS builder-bgutil-pot-arm64
LABEL builder=true multistage_tag="dggarchiver-worker-builder-bgutil-pot"
ARG BGUTIL_VERSION
WORKDIR /build
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y git pkg-config libssl-dev curl
RUN git clone https://github.com/jim60105/bgutil-ytdlp-pot-provider-rs.git --single-branch --branch ${BGUTIL_VERSION} .
RUN cargo build --release
RUN mv /build/target/release/bgutil-pot /bgutil-pot
RUN mv /build/plugin /client

FROM builder-bgutil-pot-${TARGETARCH} AS builder-bgutil-pot
LABEL builder=true multistage_tag="dggarchiver-worker-builder-bgutil-pot"

# main image
FROM python:alpine3.23 AS base-amd64
WORKDIR /app
RUN apk add --no-cache ffmpeg icu jq deno git
RUN pip install -U streamlink
RUN git clone https://github.com/CanOfSocks/livestream_dl.git
RUN python -m venv livestream_dl/venv
RUN livestream_dl/venv/bin/pip install -U -r livestream_dl/requirements.txt
RUN livestream_dl/venv/bin/pip install -U httpx[socks] yt-dlp-ejs
RUN sed -i "/if[[:space:]]\+fmt_stream\.get('targetDurationSec'):/,/^[[:space:]]*continue/s/^[[:space:]]*/&#/" "$(livestream_dl/venv/bin/pip show yt-dlp | awk '/Location/ {print $2}')/yt_dlp/extractor/youtube/_video.py"

FROM python:slim-trixie AS base-arm64
WORKDIR /app
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y ffmpeg libicu76 jq curl unzip git
RUN curl -fsSL https://deno.land/install.sh | sh
RUN pip install -U streamlink
RUN git clone https://github.com/CanOfSocks/livestream_dl.git
RUN python -m venv livestream_dl/venv
RUN livestream_dl/venv/bin/pip install -U -r livestream_dl/requirements.txt
RUN livestream_dl/venv/bin/pip install -U httpx[socks] yt-dlp-ejs
RUN sed -i "/if[[:space:]]\+fmt_stream\.get('targetDurationSec'):/,/^[[:space:]]*continue/s/^[[:space:]]*/&#/" "$(livestream_dl/venv/bin/pip show yt-dlp | awk '/Location/ {print $2}')/yt_dlp/extractor/youtube/_video.py"

FROM base-${TARGETARCH} AS base

FROM base
WORKDIR /app
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=builder /build/worker /usr/bin/
COPY --chmod=0755 ./scripts/run-worker.sh /usr/bin/run-worker
COPY --from=builder-ytarchive /go/bin/ytarchive /usr/bin/
COPY --from=builder-ytdlp /usr/bin/yt-dlp /usr/bin/
COPY --from=builder-m3u8dl /usr/bin/N_m3u8DL-RE /usr/bin/
COPY --from=builder-bgutil-pot /bgutil-pot /usr/bin/
COPY --from=builder-bgutil-pot /client /etc/yt-dlp-plugins/bgutil-ytdlp-pot-provider
CMD ["run-worker"]
