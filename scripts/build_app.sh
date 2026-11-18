#!/usr/bin/env bash
set -e

echo "🔨 [1/5] Memulai kompilasi OzillIsland (x86_64 Intel macOS)..."
swift build -c release --arch x86_64

APP_NAME="OzillIsland"
BUILD_DIR="build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "📦 [2/5] Menyiapkan struktur bundle ${APP_BUNDLE}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

echo "📋 [3/5] Menyalin Info.plist dan PkgInfo..."
cp Support/Info.plist "${CONTENTS_DIR}/Info.plist"
echo "APPL????" > "${CONTENTS_DIR}/PkgInfo"

echo "⚙️ [4/5] Menyalin binary executable dan resource bundle..."
BIN_PATH="$(swift build -c release --arch x86_64 --show-bin-path)/${APP_NAME}"
cp "${BIN_PATH}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

# Salin resource bundles dari SPM (.bundle)
SPM_BUNDLE="$(swift build -c release --arch x86_64 --show-bin-path)/OzillIsland_OzillIslandCore.bundle"
if [ -d "${SPM_BUNDLE}" ]; then
    cp -R "${SPM_BUNDLE}" "${RESOURCES_DIR}/"
fi

# Salin audio fallback langsung ke Resources bundle utama juga
cp Sources/OzillIslandCore/Resources/AdhanSample.wav "${RESOURCES_DIR}/"

echo "🔏 [5/5] Melakukan ad-hoc Code Signing lokal..."
codesign --force --deep --sign - "${APP_BUNDLE}"

echo ""
echo "🎉 Build dan packaging berhasil!"
echo "📁 Aplikasi siap dijalankan di: ${APP_BUNDLE}"
