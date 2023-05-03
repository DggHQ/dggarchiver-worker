#!/bin/ash
# shellcheck shell=dash

set -Eeuo pipefail

git clone https://github.com/nilaoda/N_m3u8DL-RE.git --single-branch --branch ${M3U8DL_VERSION} repo

# built-in upx doesnt work on alpine arm64
sed -i '/<ItemGroup Condition=/,/<\/ItemGroup>/d' repo/src/N_m3u8DL-RE/Directory.Build.props

if [ $TARGETARCH = amd64 ];
then
	dotnet publish repo/src/N_m3u8DL-RE -r linux-musl-x64 -c Release -o N_m3u8DL-RE
else
	dotnet publish repo/src/N_m3u8DL-RE -r linux-musl-arm64 -c Release -o N_m3u8DL-RE
fi

upx --best --lzma N_m3u8DL-RE/N_m3u8DL-RE