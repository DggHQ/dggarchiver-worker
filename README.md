# dggarchiver-worker
This is the worker service of the dggarchiver that will download a livestream when triggered in the queue. 

## Features

1. Supported livestream platforms:
   - YouTube
   - Rumble
   - Kick
2. Multiple downloader options:
   - YouTube: yt-dlp, yt-dlp/piped, ytarchive
   - Rumble: yt-dlp
   - Kick: yt-dlp, N_m3u8DL-RE
3. Automatically creates the thumbnails for the recorded livestreams

## Configuration

The configuration is automatically set via environment variables by the ```controller``` service that creates the worker container.