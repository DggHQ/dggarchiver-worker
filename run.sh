#!/bin/bash
set -Eeuo pipefail

# start downloading strim
case "$LIVESTREAM_PLATFORM" in
	"youtube" )
	echo "[YT] Recording $LIVESTREAM_ID with ytarchive..."
	./ytarchive -o '/videos/%(id)s' "$LIVESTREAM_URL" 720p/720p60/480p/360p/best
	;;
	"rumble" )
	echo "[Rumble] Recording $LIVESTREAM_ID with ytarchive..."
	yt-dlp -f 'best[height<=720][fps<=?30]' -o '/videos/%(id)s.%(ext)s' "$LIVESTREAM_URL"
	;;
	"kick" )
	echo "[Kick] Recording $LIVESTREAM_ID with ytarchive..."
	yt-dlp -f 'best[height<=720][fps<=?30]' -o '/videos/%(id)s.%(ext)s' "$LIVESTREAM_URL"
	;;
esac

# start processing
./dggarchiver-worker /videos/"$LIVESTREAM_ID".mp4