#!/usr/bin/env bash
set -euo pipefail

FLUTTER_VERSION="3.44.8"
FLUTTER_ARCHIVE="/tmp/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"

echo "Installing Flutter ${FLUTTER_VERSION}..."
curl -fL "$FLUTTER_URL" -o "$FLUTTER_ARCHIVE"
tar -xJf "$FLUTTER_ARCHIVE" -C /tmp

export PATH="/tmp/flutter/bin:$PATH"
export CI=true

flutter --version
flutter config --no-analytics
flutter pub get

echo "Building EcoTrack for web..."
flutter build web --release

test -f build/web/index.html
echo "EcoTrack web build completed successfully."