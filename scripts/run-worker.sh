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

VIDEO_OUT="/videos/${LIVESTREAM_PLATFORM}_${LIVESTREAM_ID}.mp4"

# Container mode for piped captures. +hybrid_fragmented writes fragments while recording (so a
# killed capture is still playable) and converts to a plain, non-fragmented MP4 in the trailer on
# a clean or graceful end. +faststart is intentionally NOT used: it needs a full-file in-place
# shift at the end, which can exceed the stop grace period and leaves a broken file if killed.
MOVFLAGS="+hybrid_fragmented"

STOPPING=0
CAPTURE_PID=""
STATUS_FILE="$(mktemp)"

# PID 1 (ash) does not act on SIGTERM by default, so a trap is needed for `docker stop` to be
# more than a delayed SIGKILL. A trap is delivered even to PID 1.
on_stop() {
	STOPPING=1
	if [ -n "$CAPTURE_PID" ]; then
		kill -TERM "$CAPTURE_PID" 2>/dev/null || true
	fi
}
trap on_stop INT TERM

# Run "<downloader> | ffmpeg" in the background so the trap above can run while it is in
# progress. ffmpeg remuxes the stream arriving on stdin into the final MP4 in one pass, so the
# recording is only ever written once and no full-size intermediate file reaches the disk.
# The ffmpeg invocation is inlined instead of wrapped in a function: ash runs a function in the
# last pipeline position in a subshell, so `$!` would be that subshell and not ffmpeg.
# The downloader's exit status is preserved through STATUS_FILE (a failed downloader must still
# fail the job), and an operator stop is treated as success so the truncated recording is still
# published.
pipe_capture() {
	: > "$STATUS_FILE"
	(
		set +e
		"$@"
		echo $? > "$STATUS_FILE"
	) | ffmpeg -nostdin -y -loglevel "repeat+info" -i pipe:0 \
		-map 0 -dn -ignore_unknown -c copy -f mp4 "-bsf:a" aac_adtstoasc \
		-movflags "$MOVFLAGS" "$VIDEO_OUT" &
	CAPTURE_PID=$! # ffmpeg, the process that has to receive the stop signal
	set +e
	wait "$CAPTURE_PID"; rc=$?
	set -e
	if [ "$STOPPING" = 1 ]; then
		# the wait above was interrupted by the stop, so let ffmpeg write the trailer
		wait "$CAPTURE_PID" 2>/dev/null || true
		CAPTURE_PID=""
		rm -f "$STATUS_FILE"
		return 0
	fi
	CAPTURE_PID=""
	status="$(cat "$STATUS_FILE" 2>/dev/null || echo 1)"
	rm -f "$STATUS_FILE"
	[ "$status" = 0 ] || return 1
	return "$rc"
}

# start downloading strim
case "$LIVESTREAM_PLATFORM" in
	"youtube" )
		echo "[$(date '+%Y-%m-%d %H:%M:%S')] [YT] Recording $LIVESTREAM_ID with ${LIVESTREAM_DOWNLOADER}..."
		if [ "${LIVESTREAM_DOWNLOADER}" = "yt-dlp" ]; then
			if [ -f "/videos/cookies.txt" ]; then
				yt-dlp -vvv --newline --cookies /videos/cookies.txt --extractor-args "youtubepot-bgutilscript:script_path=/usr/bin/bgutil-pot" --proxy "$DOWNLOAD_PROXY" --retries 25 --file-access-retries 25 --fragment-retries 25 -f "$QUALITY" -o "/videos/${LIVESTREAM_PLATFORM}_%(id)s.%(ext)s" "$LIVESTREAM_URL"
			else
				yt-dlp -vvv --newline --extractor-args "youtubepot-bgutilscript:script_path=/usr/bin/bgutil-pot" --proxy "$DOWNLOAD_PROXY" --retries 25 --file-access-retries 25 --fragment-retries 25 -f "$QUALITY" -o "/videos/${LIVESTREAM_PLATFORM}_%(id)s.%(ext)s" "$LIVESTREAM_URL"
			fi
		elif [ "${LIVESTREAM_DOWNLOADER}" = "yt-dlp/live-from-start" ]; then
			if [ -f "/videos/cookies.txt" ]; then
				yt-dlp -vvv --newline --cookies /videos/cookies.txt --extractor-args "youtubepot-bgutilscript:script_path=/usr/bin/bgutil-pot" --proxy "$DOWNLOAD_PROXY" --retries 25 --file-access-retries 25 --fragment-retries 25 -N 4 -f "$QUALITY" --live-from-start -o "/videos/${LIVESTREAM_PLATFORM}_%(id)s.%(ext)s" --exec "worker $(pwd)/info.json /videos/${LIVESTREAM_PLATFORM}_${LIVESTREAM_ID}.mp4" "$LIVESTREAM_URL"
			else
				yt-dlp -vvv --newline --extractor-args "youtubepot-bgutilscript:script_path=/usr/bin/bgutil-pot" --proxy "$DOWNLOAD_PROXY" --retries 25 --file-access-retries 25 --fragment-retries 25 -N 4 -f "$QUALITY" --live-from-start -o "/videos/${LIVESTREAM_PLATFORM}_%(id)s.%(ext)s" --exec "worker $(pwd)/info.json /videos/${LIVESTREAM_PLATFORM}_${LIVESTREAM_ID}.mp4" "$LIVESTREAM_URL"
			fi
			return
		elif [ "${LIVESTREAM_DOWNLOADER}" = "yt-dlp/piped" ]; then
			PIPED_URL=$(curl -s "https://pipedapi.kavin.rocks/streams/$LIVESTREAM_ID" | jq -r .hls)
			pipe_capture yt-dlp --proxy "$DOWNLOAD_PROXY" --retries 25 --file-access-retries 25 --downloader ffmpeg --hls-use-mpegts --downloader-args "ffmpeg_i:-nostdin -max_reload 2000 -m3u8_hold_counters 2000 -reconnect 1 -reconnect_at_eof 1 -reconnect_streamed 1 -reconnect_on_network_error 1 -reconnect_on_http_error 5xx -reconnect_delay_max 256" -f "$QUALITY" -o - "$PIPED_URL"
		elif [ "${LIVESTREAM_DOWNLOADER}" = "ytarchive" ]; then
			if [ "${DOWNLOAD_PROXY}" = "" ]; then
				PO_TOKEN=$(bgutil-pot --content-binding \""$LIVESTREAM_ID"\" | jq -r .poToken)
				export PO_TOKEN
				ytarchive --newline --potoken "$PO_TOKEN" --threads 6 -o "/videos/${LIVESTREAM_PLATFORM}_%(id)s" "$LIVESTREAM_URL" "$QUALITY"
			else
				PO_TOKEN=$(bgutil-pot --content-binding \""$LIVESTREAM_ID"\" --proxy "${DOWNLOAD_PROXY}" | jq -r .poToken)
				export PO_TOKEN
				ytarchive --proxy "$DOWNLOAD_PROXY" --newline --potoken "$PO_TOKEN" --threads 6 -o "/videos/${LIVESTREAM_PLATFORM}_%(id)s" "$LIVESTREAM_URL" "$QUALITY"
			fi
		elif [ "${LIVESTREAM_DOWNLOADER}" = "livestream_dl" ]; then
			if [ -f "/videos/cookies.txt" ]; then
				livestream_dl/venv/bin/python livestream_dl/runner.py --dash --m3u8 --cookies /videos/cookies.txt --proxy "$DOWNLOAD_PROXY" --ext "mp4" --ytdlp-options '{"extractor_args":{"youtubepot-bgutilscript":{"script_path":["/usr/bin/bgutil-pot"]}}}' --threads 4 --resolution "$QUALITY" --segment-retries 25 --output "/videos/${LIVESTREAM_PLATFORM}_%(id)s" --log-level "VERBOSE" --new-line -- "$LIVESTREAM_ID"
			else
				livestream_dl/venv/bin/python livestream_dl/runner.py --dash --m3u8 --proxy "$DOWNLOAD_PROXY" --ext "mp4" --ytdlp-options '{"extractor_args":{"youtubepot-bgutilscript":{"script_path":["/usr/bin/bgutil-pot"]}}}' --threads 4 --resolution "$QUALITY" --segment-retries 25 --output "/videos/${LIVESTREAM_PLATFORM}_%(id)s" --log-level "VERBOSE" --new-line -- "$LIVESTREAM_ID"
			fi
		elif [ "${LIVESTREAM_DOWNLOADER}" = "livestream_dl/force-m3u8" ]; then
			if [ -f "/videos/cookies.txt" ]; then
				livestream_dl/venv/bin/python livestream_dl/runner.py --dash --m3u8 --force-m3u8 --cookies /videos/cookies.txt --proxy "$DOWNLOAD_PROXY" --ext "mp4" --ytdlp-options '{"extractor_args":{"youtubepot-bgutilscript":{"script_path":["/usr/bin/bgutil-pot"]}}}' --threads 4 --resolution "$QUALITY" --segment-retries 25 --output "/videos/${LIVESTREAM_PLATFORM}_%(id)s" --log-level "VERBOSE" --new-line -- "$LIVESTREAM_ID"
			else
				livestream_dl/venv/bin/python livestream_dl/runner.py --dash --m3u8 --force-m3u8 --proxy "$DOWNLOAD_PROXY" --ext "mp4" --ytdlp-options '{"extractor_args":{"youtubepot-bgutilscript":{"script_path":["/usr/bin/bgutil-pot"]}}}' --threads 4 --resolution "$QUALITY" --segment-retries 25 --output "/videos/${LIVESTREAM_PLATFORM}_%(id)s" --log-level "VERBOSE" --new-line -- "$LIVESTREAM_ID"
			fi
		elif [ "${LIVESTREAM_DOWNLOADER}" = "streamlink" ]; then
			if [ "${DOWNLOAD_PROXY}" = "" ]; then
				if [ -f "/videos/cookies.txt" ]; then
					pipe_capture streamlink --http-cookies-file /videos/cookies.txt --stream-segment-attempts 10 --stream-timeout 120 --hls-playlist-reload-attempts 25 -O "${LIVESTREAM_URL}" "${QUALITY}"
				else
					pipe_capture streamlink --stream-segment-attempts 10 --stream-timeout 120 --hls-playlist-reload-attempts 25 -O "${LIVESTREAM_URL}" "${QUALITY}"
				fi
			else
				if [ -f "/videos/cookies.txt" ]; then
					pipe_capture streamlink --http-proxy "$DOWNLOAD_PROXY" --http-cookies-file /videos/cookies.txt --stream-segment-attempts 10 --stream-timeout 120 --hls-playlist-reload-attempts 25 -O "${LIVESTREAM_URL}" "${QUALITY}"
				else
					pipe_capture streamlink --http-proxy "$DOWNLOAD_PROXY"  --stream-segment-attempts 10 --stream-timeout 120 --hls-playlist-reload-attempts 25 -O "${LIVESTREAM_URL}" "${QUALITY}"
				fi
			fi
		else
			yt-dlp -vvv --newline --extractor-args "youtubepot-bgutilscript:script_path=/usr/bin/bgutil-pot" --proxy "$DOWNLOAD_PROXY" --retries 25 --file-access-retries 25 --fragment-retries 25 -f "$QUALITY" -o "/videos/${LIVESTREAM_PLATFORM}_%(id)s.%(ext)s" "$LIVESTREAM_URL"
		fi
		;;
	"rumble" )
		echo "[$(date '+%Y-%m-%d %H:%M:%S')] [Rumble] Recording $LIVESTREAM_ID with yt-dlp..."
		yt-dlp --proxy "$DOWNLOAD_PROXY" --retries 25 --file-access-retries 25 --downloader-args "ffmpeg_i:-nostdin -max_reload 2000 -m3u8_hold_counters 2000 -reconnect 1 -reconnect_at_eof 1 -reconnect_streamed 1 -reconnect_on_network_error 1 -reconnect_on_http_error 5xx -reconnect_delay_max 256" -f "$QUALITY" -o "/videos/${LIVESTREAM_PLATFORM}_%(id)s.%(ext)s" "$LIVESTREAM_URL"
		;;
	"kick" )
		echo "[$(date '+%Y-%m-%d %H:%M:%S')] [Kick] Recording $LIVESTREAM_ID with ${LIVESTREAM_DOWNLOADER}..."
		if [ "${LIVESTREAM_DOWNLOADER}" = "streamlink" ]; then
			if [ "${DOWNLOAD_PROXY}" = "" ]; then
				pipe_capture streamlink --stream-segment-attempts 25 --stream-timeout 600 --hls-playlist-reload-attempts 50 -O "${LIVESTREAM_URL}" "${QUALITY}"
			else
				pipe_capture streamlink --http-proxy "$DOWNLOAD_PROXY" --stream-segment-attempts 25 --stream-timeout 600 --hls-playlist-reload-attempts 50 -O "${LIVESTREAM_URL}" "${QUALITY}"
			fi
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
			pipe_capture yt-dlp --proxy "$DOWNLOAD_PROXY" --retries 25 --file-access-retries 25 --downloader ffmpeg --hls-use-mpegts --downloader-args "ffmpeg_i:-nostdin -max_reload 2000 -m3u8_hold_counters 2000 -reconnect 1 -reconnect_at_eof 1 -reconnect_streamed 1 -reconnect_on_network_error 1 -reconnect_on_http_error 5xx -reconnect_delay_max 256" -f "$QUALITY" -o - "$LIVESTREAM_URL"
		fi
		;;
	"tiktok" )
		echo "[$(date '+%Y-%m-%d %H:%M:%S')] [TikTok] Recording $LIVESTREAM_ID with streamlink..."
		if [ "${DOWNLOAD_PROXY}" = "" ]; then
			pipe_capture streamlink --stream-segment-attempts 25 --stream-timeout 600 --hls-playlist-reload-attempts 50 -O "${LIVESTREAM_URL}" "${QUALITY}"
		else
			pipe_capture streamlink --http-proxy "$DOWNLOAD_PROXY" --stream-segment-attempts 25 --stream-timeout 600 --hls-playlist-reload-attempts 50 -O "${LIVESTREAM_URL}" "${QUALITY}"
		fi
		;;
esac

# start processing
worker "$(pwd)/info.json" "$VIDEO_OUT"
