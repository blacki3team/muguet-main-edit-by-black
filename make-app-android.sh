#!/bin/sh
# muguet - make-app-android.sh
# Android 1-click build script

set -eu
cd "$(dirname "$0")"

./make-android.sh --apk "$@"
