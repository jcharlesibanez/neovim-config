#!/bin/sh
set -eu
cd "$(dirname "$0")"
mkdir -p build
clang++ -std=c++17 -O2 -fobjc-arc -mmacosx-version-min=14.2 \
  -framework Foundation -framework CoreAudio \
  -Wl,-sectcreate,__TEXT,__info_plist,Info.plist \
  main.mm -o build/system-waveform
codesign --force --sign - --identifier local.nvim.system-waveform build/system-waveform
