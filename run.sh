#!/bin/bash
echo "[$(date '+%Y-%m-%d %H:%M:%S.%N %Z')] LIVESTREAM_INFO: $LIVESTREAM_INFO"
echo "[$(date '+%Y-%m-%d %H:%M:%S.%N %Z')] LIVESTREAM_ID: $LIVESTREAM_ID"
echo "[$(date '+%Y-%m-%d %H:%M:%S.%N %Z')] LIVESTREAM_URL: $LIVESTREAM_URL"
echo "[$(date '+%Y-%m-%d %H:%M:%S.%N %Z')] LIVESTREAM_PLATFORM: $LIVESTREAM_PLATFORM"
echo "[$(date '+%Y-%m-%d %H:%M:%S.%N %Z')] NATS_HOST: $NATS_HOST"
echo "[$(date '+%Y-%m-%d %H:%M:%S.%N %Z')] NATS_TOPIC: $NATS_TOPIC"
echo "[$(date '+%Y-%m-%d %H:%M:%S.%N %Z')] VERBOSE: $VERBOSE"

set -Eeuo pipefail

# start downloading strim
case "$LIVESTREAM_PLATFORM" in
	"youtube" )
		echo "[$(date '+%Y-%m-%d %H:%M:%S.%N %Z')] [YT] Recording $LIVESTREAM_ID with ytarchive..."
		./ytarchive -o "/videos/${LIVESTREAM_PLATFORM}_%(id)s" "$LIVESTREAM_URL" 720p/720p60/480p/360p/best
		;;
	"rumble" )
		echo "[$(date '+%Y-%m-%d %H:%M:%S.%N %Z')] [Rumble] Recording $LIVESTREAM_ID with yt-dlp..."
		yt-dlp -f 'best[height=720][fps=30] / best[height=720][fps=60] / best[height=480] / best[height=360] / best' -o "/videos/${LIVESTREAM_PLATFORM}_%(id)s.%(ext)s" "$LIVESTREAM_URL"
		;;
	"kick" )
		echo "[$(date '+%Y-%m-%d %H:%M:%S.%N %Z')] [Kick] Recording $LIVESTREAM_ID with yt-dlp..."
		yt-dlp --downloader ffmpeg --hls-use-mpegts -f 'best[height=720][fps=30] / best[height=720][fps=60] / best[height=480] / best[height=360] / best' -o "/videos/${LIVESTREAM_PLATFORM}_${LIVESTREAM_ID}_temp.%(ext)s" "$LIVESTREAM_URL"
		ffmpeg -y -loglevel "repeat+info" -i "/videos/${LIVESTREAM_PLATFORM}_${LIVESTREAM_ID}_temp.mp4" -map 0 -dn -ignore_unknown -c copy -f mp4 "-bsf:a" aac_adtstoasc -movflags "+faststart" "/videos/${LIVESTREAM_PLATFORM}_${LIVESTREAM_ID}.mp4"
		rm "/videos/${LIVESTREAM_PLATFORM}_${LIVESTREAM_ID}_temp.mp4"
		;;
esac

# start processing
./dggarchiver-worker /videos/"${LIVESTREAM_PLATFORM}_${LIVESTREAM_ID}".mp4