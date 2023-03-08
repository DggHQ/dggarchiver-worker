#!/bin/bash
set -Eeuo pipefail

# start downloading strim
./ytarchive -o '/videos/%(id)s' "https://youtu.be/$LIVESTREAM_ID" 720p/720p60/480p/360p/best

# start processing
./dggarchiver-worker /videos/"$LIVESTREAM_ID".mp4