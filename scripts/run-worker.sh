#!/bin/ash
#shellcheck shell=dash

echo "[$(date '+%Y-%m-%d %H:%M:%S')] LIVESTREAM_INFO: $LIVESTREAM_INFO"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] LIVESTREAM_ID: $LIVESTREAM_ID"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] LIVESTREAM_URL: $LIVESTREAM_URL"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] LIVESTREAM_PLATFORM: $LIVESTREAM_PLATFORM"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] LIVESTREAM_DOWNLOADER: $LIVESTREAM_DOWNLOADER"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] QUALITY: $QUALITY"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] NATS_HOST: $NATS_HOST"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] NATS_TOPIC: $NATS_TOPIC"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] DOWNLOAD_PROXY: $DOWNLOAD_PROXY"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] VERBOSE: $VERBOSE"

set -Eeuo pipefail

echo "$LIVESTREAM_INFO" > "$(pwd)/info.json"

# start downloading strim
case "$LIVESTREAM_PLATFORM" in
	"youtube" )
		echo "[$(date '+%Y-%m-%d %H:%M:%S')] [YT] Recording $LIVESTREAM_ID with ${LIVESTREAM_DOWNLOADER}..."
		if [ "${LIVESTREAM_DOWNLOADER}" = "yt-dlp" ]; then
			yt-dlp --proxy "$DOWNLOAD_PROXY" --retries 25 --file-access-retries 25 -f "$QUALITY" -o "/videos/${LIVESTREAM_PLATFORM}_%(id)s.%(ext)s" "$LIVESTREAM_URL"
		elif [ "${LIVESTREAM_DOWNLOADER}" = "yt-dlp/piped" ]; then
			PIPED_URL=$(curl -s "https://pipedapi.kavin.rocks/streams/$LIVESTREAM_ID" | jq -r .hls)
			yt-dlp --proxy "$DOWNLOAD_PROXY" --retries 25 --file-access-retries 25 --downloader ffmpeg --hls-use-mpegts --downloader-args "ffmpeg_i:-nostdin -max_reload 2000 -m3u8_hold_counters 2000 -reconnect 1 -reconnect_at_eof 1 -reconnect_streamed 1 -reconnect_on_network_error 1 -reconnect_on_http_error 5xx -reconnect_delay_max 256" -f "$QUALITY"  -o "/videos/${LIVESTREAM_PLATFORM}_${LIVESTREAM_ID}_temp.%(ext)s" "$PIPED_URL"
			ffmpeg -nostdin -y -loglevel "repeat+info" -i "/videos/${LIVESTREAM_PLATFORM}_${LIVESTREAM_ID}_temp.mp4" -map 0 -dn -ignore_unknown -c copy -f mp4 "-bsf:a" aac_adtstoasc -movflags "+faststart" "/videos/${LIVESTREAM_PLATFORM}_${LIVESTREAM_ID}.mp4"
			rm "/videos/${LIVESTREAM_PLATFORM}_${LIVESTREAM_ID}_temp.mp4"
		elif [ "${LIVESTREAM_DOWNLOADER}" = "ytarchive" ]; then
			if [ "${DOWNLOAD_PROXY}" = "" ]; then
				ytarchive --newline --threads 6 -o "/videos/${LIVESTREAM_PLATFORM}_%(id)s" "$LIVESTREAM_URL" "$QUALITY"
			else
				ytarchive --proxy "$DOWNLOAD_PROXY" --newline --threads 6 -o "/videos/${LIVESTREAM_PLATFORM}_%(id)s" "$LIVESTREAM_URL" "$QUALITY"
			fi
		else
			yt-dlp --proxy "$DOWNLOAD_PROXY" --retries 25 --file-access-retries 25 -f "$QUALITY" -o "/videos/${LIVESTREAM_PLATFORM}_%(id)s.%(ext)s" "$LIVESTREAM_URL"
		fi
		;;
	"rumble" )
		echo "[$(date '+%Y-%m-%d %H:%M:%S')] [Rumble] Recording $LIVESTREAM_ID with yt-dlp..."
		yt-dlp --proxy "$DOWNLOAD_PROXY" --retries 25 --file-access-retries 25 --downloader-args "ffmpeg_i:-nostdin -max_reload 2000 -m3u8_hold_counters 2000 -reconnect 1 -reconnect_at_eof 1 -reconnect_streamed 1 -reconnect_on_network_error 1 -reconnect_on_http_error 5xx -reconnect_delay_max 256" -f "$QUALITY" -o "/videos/${LIVESTREAM_PLATFORM}_%(id)s.%(ext)s" "$LIVESTREAM_URL"
		;;
	"kick" )
		echo "[$(date '+%Y-%m-%d %H:%M:%S')] [Kick] Recording $LIVESTREAM_ID with ${LIVESTREAM_DOWNLOADER}..."
		export TMP_EXTENSION='mp4'
		if [ "${LIVESTREAM_DOWNLOADER}" = "yt-dlp" ]; then
			yt-dlp --proxy "$DOWNLOAD_PROXY" --retries 25 --file-access-retries 25 --downloader ffmpeg --hls-use-mpegts --downloader-args "ffmpeg_i:-nostdin -max_reload 2000 -m3u8_hold_counters 2000 -reconnect 1 -reconnect_at_eof 1 -reconnect_streamed 1 -reconnect_on_network_error 1 -reconnect_on_http_error 5xx -reconnect_delay_max 256" -f "$QUALITY" -o "/videos/${LIVESTREAM_PLATFORM}_${LIVESTREAM_ID}_temp.%(ext)s" "$LIVESTREAM_URL"
			ffmpeg -nostdin -y -loglevel "repeat+info" -i "/videos/${LIVESTREAM_PLATFORM}_${LIVESTREAM_ID}_temp.${TMP_EXTENSION}" -map 0 -dn -ignore_unknown -c copy -f mp4 "-bsf:a" aac_adtstoasc -movflags "+faststart" "/videos/${LIVESTREAM_PLATFORM}_${LIVESTREAM_ID}.mp4"
			rm "/videos/${LIVESTREAM_PLATFORM}_${LIVESTREAM_ID}_temp.${TMP_EXTENSION}"
		elif [ "${LIVESTREAM_DOWNLOADER}" = "streamlink" ]; then
			if [ "${DOWNLOAD_PROXY}" = "" ]; then
				streamlink --stream-segment-attempts 25 --stream-timeout 600 --hls-playlist-reload-attempts 50 -o "/videos/${LIVESTREAM_PLATFORM}_${LIVESTREAM_ID}_temp.${TMP_EXTENSION}" "${LIVESTREAM_URL}" "${QUALITY}"
			else
				streamlink --http-proxy "$DOWNLOAD_PROXY" --stream-segment-attempts 25 --stream-timeout 600 --hls-playlist-reload-attempts 50 -o "/videos/${LIVESTREAM_PLATFORM}_${LIVESTREAM_ID}_temp.${TMP_EXTENSION}" "${LIVESTREAM_URL}" "${QUALITY}"
			fi
			ffmpeg -nostdin -y -loglevel "repeat+info" -i "/videos/${LIVESTREAM_PLATFORM}_${LIVESTREAM_ID}_temp.${TMP_EXTENSION}" -map 0 -dn -ignore_unknown -c copy -f mp4 "-bsf:a" aac_adtstoasc -movflags "+faststart" "/videos/${LIVESTREAM_PLATFORM}_${LIVESTREAM_ID}.mp4"
			rm "/videos/${LIVESTREAM_PLATFORM}_${LIVESTREAM_ID}_temp.${TMP_EXTENSION}"
		elif [ "${LIVESTREAM_DOWNLOADER}" = "N_m3u8DL-RE" ]; then
			TMP_EXTENSION='ts'
			if [ "${DOWNLOAD_PROXY}" = "" ]; then
				N_m3u8DL-RE "$LIVESTREAM_URL" --save-dir /videos/ --save-name "${LIVESTREAM_PLATFORM}_${LIVESTREAM_ID}_temp" -sv res="$QUALITY" -M format=mp4 --live-real-time-merge --live-pipe-mux --live-keep-segments=false
			else
				N_m3u8DL-RE "$LIVESTREAM_URL" --custom-proxy "$DOWNLOAD_PROXY" --save-dir /videos/ --save-name "${LIVESTREAM_PLATFORM}_${LIVESTREAM_ID}_temp" -sv res="$QUALITY" -M format=mp4 --live-real-time-merge --live-pipe-mux --live-keep-segments=false
			fi
			ffmpeg -nostdin -y -loglevel "repeat+info" -i "/videos/${LIVESTREAM_PLATFORM}_${LIVESTREAM_ID}_temp.${TMP_EXTENSION}" -map 0 -dn -ignore_unknown -c copy -f mp4 "-bsf:a" aac_adtstoasc -movflags "+faststart" "/videos/${LIVESTREAM_PLATFORM}_${LIVESTREAM_ID}.mp4"
			rm "/videos/${LIVESTREAM_PLATFORM}_${LIVESTREAM_ID}_temp.${TMP_EXTENSION}"
		else
			yt-dlp --proxy "$DOWNLOAD_PROXY" --retries 25 --file-access-retries 25 --downloader ffmpeg --hls-use-mpegts --downloader-args "ffmpeg_i:-nostdin -max_reload 2000 -m3u8_hold_counters 2000 -reconnect 1 -reconnect_at_eof 1 -reconnect_streamed 1 -reconnect_on_network_error 1 -reconnect_on_http_error 5xx -reconnect_delay_max 256" -f "$QUALITY" -o "/videos/${LIVESTREAM_PLATFORM}_${LIVESTREAM_ID}_temp.%(ext)s" "$LIVESTREAM_URL"
			ffmpeg -nostdin -y -loglevel "repeat+info" -i "/videos/${LIVESTREAM_PLATFORM}_${LIVESTREAM_ID}_temp.${TMP_EXTENSION}" -map 0 -dn -ignore_unknown -c copy -f mp4 "-bsf:a" aac_adtstoasc -movflags "+faststart" "/videos/${LIVESTREAM_PLATFORM}_${LIVESTREAM_ID}.mp4"
			rm "/videos/${LIVESTREAM_PLATFORM}_${LIVESTREAM_ID}_temp.${TMP_EXTENSION}"
		fi
		;;
esac

# start processing
worker "$(pwd)/info.json" /videos/"${LIVESTREAM_PLATFORM}_${LIVESTREAM_ID}".mp4
