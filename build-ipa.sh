#!/bin/bash
# 在 macOS 上一键构建未签名 Sivan.ipa
# 用法: ./build-ipa.sh
set -euo pipefail

cd "$(dirname "$0")"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "❌ 没找到 xcodebuild，请先安装 Xcode 并执行 sudo xcode-select -s /Applications/Xcode.app"
  exit 1
fi

# 没有 .xcodeproj 时用 xcodegen 生成
if [ ! -d "Sivan.xcodeproj" ]; then
  if command -v xcodegen >/dev/null 2>&1; then
    echo "▶︎ 用 XcodeGen 生成工程…"
    xcodegen generate
  else
    echo "❌ 缺少 Sivan.xcodeproj，且未安装 xcodegen（brew install xcodegen）"
    exit 1
  fi
fi

echo "▶︎ 编译中（Release / iphoneos / 不签名）…"
xcodebuild \
  -project Sivan.xcodeproj \
  -scheme Sivan \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  DEVELOPMENT_TEAM="" \
  OTHER_CODE_SIGN_FLAGS="" \
  clean build

APP_PATH=$(ls -d build/Build/Products/Release-iphoneos/*.app | head -n 1)
echo "▶︎ 打包: $APP_PATH"

rm -rf out
mkdir -p out/Payload
cp -R "$APP_PATH" out/Payload/
[ -d "out/Payload/Sivan.app/_CodeSignature" ] && rm -rf "out/Payload/Sivan.app/_CodeSignature"

cd out
zip -qry Sivan.ipa Payload
cd ..

echo ""
echo "✅ 完成: $(pwd)/out/Sivan.ipa"
ls -lh out/Sivan.ipa
echo "把 Sivan.ipa 拖进 Sideloadly / AltStore / 爱思助手 用你自己的 Apple ID 签名安装即可。"
