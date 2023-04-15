FROM golang:alpine as builder
ARG M3U8DL_PLATFORM='linux-x64'
ARG TARGETARCH
LABEL builder=true multistage_tag="dggarchiver-worker-builder"
WORKDIR /app
COPY . .
RUN apk add --no-cache curl jq
RUN if [ "$TARGETARCH" = "arm64" ] ; then export M3U8DL_PLATFORM='linux-arm64' ; fi &&\ 
	curl https://api.github.com/repos/nilaoda/N_m3u8DL-RE/releases/latest\ 
	| jq -r ".assets[] | select(.browser_download_url | contains(\"${M3U8DL_PLATFORM}\")) | .browser_download_url"\ 
	| xargs wget -O m3u8dl.tar.gz\ 
	&& tar zxf m3u8dl.tar.gz --strip-components 1\ 
	&& rm m3u8dl.tar.gz\ 
	&& chmod +x ./N_m3u8DL-RE
RUN GOOS=linux GOARCH=${TARGETARCH} go install github.com/Kethsar/ytarchive@v0.3.2
RUN GOOS=linux GOARCH=${TARGETARCH} go build -v

FROM python:alpine3.17
WORKDIR /app
COPY --from=builder /app/dggarchiver-worker .
COPY --from=builder /app/run.sh .
COPY --from=builder /go/bin/ytarchive /usr/bin/
COPY --from=builder /app/N_m3u8DL-RE /usr/bin/
RUN apk add --no-cache bash ffmpeg
RUN pip install -U yt-dlp
RUN chmod +x ./run.sh
CMD ["./run.sh"]