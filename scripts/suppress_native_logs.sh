#!/bin/bash

# Androidのデバッグ用システムログを抑制するスクリプト
# CCodec, MediaCodec, LegacyGraphicsTrackerなどのノイズとなるログを抑制します。

TAGS=(
  "CCodec"
  "CCodecConfig"
  "MediaCodec"
  "LegacyGraphicsTracker"
  "AidlBufferPool"
  "AidlBufferPoolAcc"
  "WindowOnBackDispatcher"
  "InsetsController"
  "ImeTracker"
  "Surface"
  "SurfaceUtils"
  "AudioSystem"
  "ExoPlayerImpl"
  "VideoCapabilities"
  "ReflectedParamUpdater"
  "Codec2Client"
  "DMCodecAdapterFactory"
  "ApexCodecsLazy"
  "ColorUtils"
  "ProfileInstaller"
  "AssistStructure"
)

echo "Setting adb log.tag properties to WARN to suppress debug/info logs..."

# デバイスが接続されているか確認
if ! adb devices | grep -q -E "device$"; then
  echo "Warning: No Android devices/emulators found. Please start an emulator or connect a device."
  exit 1
fi

for tag in "${TAGS[@]}"; do
  echo "Suppressing tag: $tag"
  adb shell setprop log.tag.$tag WARN
  # 再起動後も維持したい場合は persist も設定
  adb shell setprop persist.log.tag.$tag WARN
done

echo "Successfully configured log.tag properties."
echo "Please restart your Flutter app (press 'R' in flutter run) to see the changes."
