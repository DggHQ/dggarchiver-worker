#!/bin/ash
#shellcheck shell=dash

echo "[$(date '+%Y-%m-%d %H:%M:%S')] LIVESTREAM_INFO: $LIVESTREAM_INFO"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] LIVESTREAM_ID: $LIVESTREAM_ID"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] LIVESTREAM_URL: $LIVESTREAM_URL"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] LIVESTREAM_PLATFORM: $LIVESTREAM_PLATFORM"
if [ "$LIVESTREAM_PLATFORM" = "kick" ]; then
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] KICK_DOWNLOADER: $KICK_DOWNLOADER"
fi
echo "[$(date '+%Y-%m-%d %H:%M:%S')] NATS_HOST: $NATS_HOST"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] NATS_TOPIC: $NATS_TOPIC"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] VERBOSE: $VERBOSE"

set -Eeuo pipefail

# start downloading strim
case "$LIVESTREAM_PLATFORM" in
	"youtube" )
		echo "[$(date '+%Y-%m-%d %H:%M:%S')] [YT] Recording $LIVESTREAM_ID with ytarchive..."
		ytarchive -o "/videos/${LIVESTREAM_PLATFORM}_%(id)s" "$LIVESTREAM_URL" 720p/720p60/480p/360p/best
		;;
	"rumble" )
		echo "[$(date '+%Y-%m-%d %H:%M:%S')] [Rumble] Recording $LIVESTREAM_ID with yt-dlp..."
		yt-dlp -f 'best[height=720][fps=30] / best[height=720] / best[height=480] / best[height=360] / best' -o "/videos/${LIVESTREAM_PLATFORM}_%(id)s.%(ext)s" "$LIVESTREAM_URL"
		;;
	"kick" )
		echo "[$(date '+%Y-%m-%d %H:%M:%S')] [Kick] Recording $LIVESTREAM_ID with ${KICK_DOWNLOADER:=yt-dlp}..."
		export TMP_EXTENSION='mp4'
		if [ "${KICK_DOWNLOADER}" = "yt-dlp" ]; then
			yt-dlp --downloader ffmpeg --hls-use-mpegts -f 'best[height=720][fps=30] / best[height=720] / best[height=480] / best[height=360] / best' -o "/videos/${LIVESTREAM_PLATFORM}_${LIVESTREAM_ID}_temp.%(ext)s" "$LIVESTREAM_URL"
		elif [ "${KICK_DOWNLOADER}" = "N_m3u8DL-RE" ]; then
			TMP_EXTENSION='ts'
			N_m3u8DL-RE "$LIVESTREAM_URL" --save-dir /videos/ --save-name "${LIVESTREAM_PLATFORM}_${LIVESTREAM_ID}_temp" -sv res="720|480|360" -M format=mp4 --live-real-time-merge --live-pipe-mux --live-keep-segments=false
		else
			yt-dlp --downloader ffmpeg --hls-use-mpegts -f 'best[height=720][fps=30] / best[height=720] / best[height=480] / best[height=360] / best' -o "/videos/${LIVESTREAM_PLATFORM}_${LIVESTREAM_ID}_temp.%(ext)s" "$LIVESTREAM_URL"
		fi
		ffmpeg -y -loglevel "repeat+info" -i "/videos/${LIVESTREAM_PLATFORM}_${LIVESTREAM_ID}_temp.${TMP_EXTENSION}" -map 0 -dn -ignore_unknown -c copy -f mp4 "-bsf:a" aac_adtstoasc -movflags "+faststart" "/videos/${LIVESTREAM_PLATFORM}_${LIVESTREAM_ID}.mp4"
		rm "/videos/${LIVESTREAM_PLATFORM}_${LIVESTREAM_ID}_temp.${TMP_EXTENSION}"
		;;
esac

# start processing
worker /videos/"${LIVESTREAM_PLATFORM}_${LIVESTREAM_ID}".mp4