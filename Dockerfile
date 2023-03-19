FROM golang:alpine as builder
ARG TARGETARCH
LABEL builder=true multistage_tag="dggarchiver-worker-builder"
WORKDIR /app
COPY . .
RUN GOOS=linux GOARCH=${TARGETARCH} go install github.com/Kethsar/ytarchive@v0.3.2
RUN GOOS=linux GOARCH=${TARGETARCH} go build

FROM python:alpine3.17
WORKDIR /app
COPY --from=builder /app/dggarchiver-worker .
COPY --from=builder /app/run.sh .
COPY --from=builder /go/bin/ytarchive .
RUN apk add --no-cache bash ffmpeg
RUN pip install -U yt-dlp
RUN chmod +x ./run.sh
CMD ["./run.sh"]