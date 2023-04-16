FROM golang:alpine as builder-go
ARG YTARCHIVE_VERSION='v0.3.2'
ARG TARGETARCH
LABEL builder=true multistage_tag="dggarchiver-worker-builder-go"
WORKDIR /app
COPY . .
RUN GOOS=linux GOARCH=${TARGETARCH} go install github.com/Kethsar/ytarchive@${YTARCHIVE_VERSION}
RUN GOOS=linux GOARCH=${TARGETARCH} go build -v

FROM mcr.microsoft.com/dotnet/sdk:7.0-alpine as builder-dotnet
ARG M3U8DL_VERSION='v0.1.6-beta'
ARG M3U8DL_PLATFORM='linux-musl-x64'
ARG TARGETARCH
LABEL builder=true multistage_tag="dggarchiver-worker-builder-dotnet"
WORKDIR /app
RUN apk add --no-cache git build-base icu-dev curl-dev zlib-dev krb5-dev
RUN git clone https://github.com/nilaoda/N_m3u8DL-RE.git --single-branch --branch ${M3U8DL_VERSION} repo
RUN if [ "$TARGETARCH" = "arm64" ] ; then export M3U8DL_PLATFORM='linux-arm64' ; fi &&\ 
	dotnet publish repo/src/N_m3u8DL-RE -r ${M3U8DL_PLATFORM} -c Release -o N_m3u8DL-RE

FROM python:alpine3.17
WORKDIR /app
COPY --from=builder-go /app/dggarchiver-worker .
COPY --from=builder-go /app/run.sh .
COPY --from=builder-go /go/bin/ytarchive /usr/bin/
COPY --from=builder-dotnet /app/N_m3u8DL-RE /usr/bin/
RUN apk add --no-cache bash ffmpeg icu
RUN pip install -U yt-dlp
RUN chmod +x ./run.sh
CMD ["./run.sh"]