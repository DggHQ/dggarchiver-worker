#!/bin/sh

git clone https://github.com/nilaoda/N_m3u8DL-RE.git --single-branch --branch "${M3U8DL_VERSION}" repo
sed -i '/<ItemGroup Condition=/,/<\/ItemGroup>/d' repo/src/N_m3u8DL-RE/Directory.Build.props
sed -i 's/<\/Project>/<ItemGroup><PackageReference Include="Microsoft.DotNet.ILCompiler; runtime.linux-x64.Microsoft.DotNet.ILCompiler; runtime.linux-musl-x64.Microsoft.DotNet.ILCompiler" Version="8.0.0-*" \/><\/ItemGroup><\/Project>/' repo/src/N_m3u8DL-RE/Directory.Build.props

if [ "$TARGETARCH" = amd64 ];
then
	/root/.dotnet/dotnet publish repo/src/N_m3u8DL-RE -r linux-musl-x64 -c Release -o artifacts
else
	sed -i "s/== 'linux-arm64'/== 'linux-musl-arm64'/" repo/src/N_m3u8DL-RE/Directory.Build.props
	sed -i 's/aarch64-linux-gnu-objcopy/aarch64-alpine-linux-musl-objcopy/' repo/src/N_m3u8DL-RE/Directory.Build.props
	/root/.dotnet/dotnet publish repo/src/N_m3u8DL-RE -r linux-musl-arm64 -c Release -p:StripSymbols=true -p:CppCompilerAndLinker=clang-18 -p:SysRoot=/crossrootfs/arm64 -o artifacts
fi

upx --best --lzma artifacts/N_m3u8DL-RE
