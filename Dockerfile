FROM golang:alpine as builder
LABEL builder=true multistage_tag="dggarchiver-worker-builder"
WORKDIR /app
COPY . .
RUN GOOS=linux GOARCH=amd64 go build

FROM alpine:3.17
WORKDIR /app
COPY --from=builder /app/dggarchiver-worker .
COPY --from=builder /app/run.sh .
RUN apk add --no-cache bash ffmpeg curl gzip
RUN curl -sL $(curl -s https://api.github.com/repos/Kethsar/ytarchive/releases/latest | grep browser_download_url | cut -d\" -f4 | grep -E 'ytarchive_linux_amd64.zip$') | zcat >> ytarchive
RUN chmod +x ./ytarchive
RUN chmod +x ./run.sh
CMD ["./run.sh"]