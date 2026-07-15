#!/usr/bin/env bash
# Builds QuitOnClose.app from source into ./dist
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="QuitOnClose"
BUILD_DIR=".build/release"
APP_BUNDLE="dist/${APP_NAME}.app"

echo "==> Compilo il binario (release)"
swift build -c release

echo "==> Assemblo ${APP_BUNDLE}"
rm -rf dist
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"
cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp "Resources/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"

echo "==> Firma ad-hoc"
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "==> Fatto: ${APP_BUNDLE}"
