#!/bin/ash
#shellcheck shell=dash

echo "[$(date '+%Y-%m-%d %H:%M:%S')] LIVESTREAM_INFO: $LIVESTREAM_INFO"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] LIVESTREAM_ID: $LIVESTREAM_ID"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] LIVESTREAM_URL: $LIVESTREAM_URL"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] LIVESTREAM_PLATFORM: $LIVESTREAM_PLATFORM"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] LIVESTREAM_DOWNLOADER: $LIVESTREAM_DOWNLOADER"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] NATS_HOST: $NATS_HOST"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] NATS_TOPIC: $NATS_TOPIC"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] VERBOSE: $VERBOSE"

set -Eeuo pipefail

# start downloading strim
case "$LIVESTREAM_PLATFORM" in
	"youtube" )
		echo "[$(date '+%Y-%m-%d %H:%M:%S')] [YT] Recording $LIVESTREAM_ID with ${LIVESTREAM_DOWNLOADER}..."
		if [ "${LIVESTREAM_DOWNLOADER}" = "yt-dlp" ]; then
			yt-dlp --retries 25 --file-access-retries 25 -f 'best[height=720][fps=30] / best[height=720] / best[height=480] / best[height=360] / best' -o "/videos/${LIVESTREAM_PLATFORM}_%(id)s.%(ext)s" "$LIVESTREAM_URL"
		elif [ "${LIVESTREAM_DOWNLOADER}" = "yt-dlp/piped" ]; then
			PIPED_URL=$(curl -s "https://pipedapi.kavin.rocks/streams/$LIVESTREAM_ID" | jq -r .hls)
			yt-dlp --retries 25 --file-access-retries 25 --downloader ffmpeg --hls-use-mpegts --downloader-args ffmpeg:'-max_reload 75 -m3u8_hold_counters 75 -reconnect 1 -reconnect_at_eof 1 -reconnect_streamed 1 -reconnect_on_network_error 1 -reconnect_on_http_error 504 -reconnect_delay_max 256' -f 'bestvideo[height=720][fps=30]+bestaudio / bestvideo[height=720]+bestaudio / bestvideo[height=480]+bestaudio / bestvideo[height=360]+bestaudio / bestvideo+bestaudio' -o "/videos/${LIVESTREAM_PLATFORM}_${LIVESTREAM_ID}_temp.%(ext)s" "$PIPED_URL"
			ffmpeg -y -loglevel "repeat+info" -i "/videos/${LIVESTREAM_PLATFORM}_${LIVESTREAM_ID}_temp.mp4" -map 0 -dn -ignore_unknown -c copy -f mp4 "-bsf:a" aac_adtstoasc -movflags "+faststart" "/videos/${LIVESTREAM_PLATFORM}_${LIVESTREAM_ID}.mp4"
			rm "/videos/${LIVESTREAM_PLATFORM}_${LIVESTREAM_ID}_temp.mp4"
		elif [ "${LIVESTREAM_DOWNLOADER}" = "ytarchive" ]; then
			ytarchive --threads 2 -o "/videos/${LIVESTREAM_PLATFORM}_%(id)s" "$LIVESTREAM_URL" 720p/720p60/480p/360p/best
		else
			yt-dlp --retries 25 --file-access-retries 25 -f 'best[height=720][fps=30] / best[height=720] / best[height=480] / best[height=360] / best' -o "/videos/${LIVESTREAM_PLATFORM}_%(id)s.%(ext)s" "$LIVESTREAM_URL"
		fi
		;;
	"rumble" )
		echo "[$(date '+%Y-%m-%d %H:%M:%S')] [Rumble] Recording $LIVESTREAM_ID with yt-dlp..."
		yt-dlp --retries 25 --file-access-retries 25 --downloader-args ffmpeg:'-max_reload 75 -m3u8_hold_counters 75 -reconnect 1 -reconnect_at_eof 1 -reconnect_streamed 1 -reconnect_on_network_error 1 -reconnect_on_http_error 504 -reconnect_delay_max 256' -f 'best[height=720][fps=30] / best[height=720] / best[height=480] / best[height=360] / best' -o "/videos/${LIVESTREAM_PLATFORM}_%(id)s.%(ext)s" "$LIVESTREAM_URL"
		;;
	"kick" )
		echo "[$(date '+%Y-%m-%d %H:%M:%S')] [Kick] Recording $LIVESTREAM_ID with ${LIVESTREAM_DOWNLOADER}..."
		export TMP_EXTENSION='mp4'
		if [ "${LIVESTREAM_DOWNLOADER}" = "yt-dlp" ]; then
			yt-dlp --retries 25 --file-access-retries 25 --downloader ffmpeg --hls-use-mpegts --downloader-args ffmpeg:'-max_reload 75 -m3u8_hold_counters 75 -reconnect 1 -reconnect_at_eof 1 -reconnect_streamed 1 -reconnect_on_network_error 1 -reconnect_on_http_error 504 -reconnect_delay_max 256' -f 'best[height=720][fps=30] / best[height=720] / best[height=480] / best[height=360] / best' -o "/videos/${LIVESTREAM_PLATFORM}_${LIVESTREAM_ID}_temp.%(ext)s" "$LIVESTREAM_URL"
		elif [ "${LIVESTREAM_DOWNLOADER}" = "N_m3u8DL-RE" ]; then
			TMP_EXTENSION='ts'
			N_m3u8DL-RE "$LIVESTREAM_URL" --save-dir /videos/ --save-name "${LIVESTREAM_PLATFORM}_${LIVESTREAM_ID}_temp" -sv res="720|480|360" -M format=mp4 --live-real-time-merge --live-pipe-mux --live-keep-segments=false
		else
			yt-dlp --retries 25 --file-access-retries 25 --downloader ffmpeg --hls-use-mpegts --downloader-args ffmpeg:'-max_reload 75 -m3u8_hold_counters 75 -reconnect 1 -reconnect_at_eof 1 -reconnect_streamed 1 -reconnect_on_network_error 1 -reconnect_on_http_error 504 -reconnect_delay_max 256' -f 'best[height=720][fps=30] / best[height=720] / best[height=480] / best[height=360] / best' -o "/videos/${LIVESTREAM_PLATFORM}_${LIVESTREAM_ID}_temp.%(ext)s" "$LIVESTREAM_URL"
		fi
		ffmpeg -y -loglevel "repeat+info" -i "/videos/${LIVESTREAM_PLATFORM}_${LIVESTREAM_ID}_temp.${TMP_EXTENSION}" -map 0 -dn -ignore_unknown -c copy -f mp4 "-bsf:a" aac_adtstoasc -movflags "+faststart" "/videos/${LIVESTREAM_PLATFORM}_${LIVESTREAM_ID}.mp4"
		rm "/videos/${LIVESTREAM_PLATFORM}_${LIVESTREAM_ID}_temp.${TMP_EXTENSION}"
		;;
esac

# start processing
worker /videos/"${LIVESTREAM_PLATFORM}_${LIVESTREAM_ID}".mp4