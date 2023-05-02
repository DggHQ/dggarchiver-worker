#!/bin/ash
# shellcheck shell=dash

set -Eeuo pipefail

git clone https://github.com/nilaoda/N_m3u8DL-RE.git --single-branch --branch ${M3U8DL_VERSION} repo

if [ $TARGETARCH = amd64 ];
then
	dotnet publish repo/src/N_m3u8DL-RE -r linux-musl-x64 -c Release -o N_m3u8DL-RE
else
	apk add --no-cache curl jq
	export M3U8DL_URL=$(curl -s https://api.github.com/repos/nilaoda/N_m3u8DL-RE/releases/latest | jq -r ".assets[] | select(.browser_download_url | contains(\"linux-arm64\")) | .browser_download_url")
	echo $M3U8DL_URL | xargs wget -O m3u8dl.tar.gz
	tar zxf m3u8dl.tar.gz --strip-components 1
	rm m3u8dl.tar.gz
	chmod +x ./N_m3u8DL-RE
fi