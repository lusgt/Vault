#!/usr/bin/env bash
# 用法：
#   ./scripts/build_dmg.sh          # 版本号自动取最新 git tag，无 tag 则用 "dev"
#   ./scripts/build_dmg.sh 1.0.0    # 手动指定版本号
set -euo pipefail

PROJECT="Vault.xcodeproj"
TARGET="Vault"
APP_NAME="Vault"
CONFIGURATION="Release"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/build"
APP_PATH="${BUILD_DIR}/Build/Products/${CONFIGURATION}/${APP_NAME}.app"

# 版本号：优先用参数，否则取最新 git tag，都没有则用 "dev"
VERSION="${1:-$(git -C "${ROOT_DIR}" describe --tags --abbrev=0 2>/dev/null || echo "dev")}"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_PATH="${ROOT_DIR}/${DMG_NAME}"

echo "→ Building ${APP_NAME} ${VERSION} (${CONFIGURATION})..."
rm -rf "${BUILD_DIR}"

xcodebuild \
  -project "${ROOT_DIR}/${PROJECT}" \
  -scheme "${TARGET}" \
  -configuration "${CONFIGURATION}" \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  build \
  -derivedDataPath "${BUILD_DIR}" \
  > /dev/null

if [[ ! -d "${APP_PATH}" ]]; then
  echo "✗ Build failed: ${APP_PATH} not found" >&2
  exit 1
fi
echo "✓ Build succeeded"

echo "→ Creating DMG..."
TMP_DIR="$(mktemp -d)"
VOL_DIR="${TMP_DIR}/${APP_NAME}"
mkdir -p "${VOL_DIR}"
cp -R "${APP_PATH}" "${VOL_DIR}/"
ln -s /Applications "${VOL_DIR}/Applications"

rm -f "${DMG_PATH}"
hdiutil create \
  -volname "${APP_NAME}" \
  -srcfolder "${VOL_DIR}" \
  -ov \
  -format UDZO \
  "${DMG_PATH}" \
  > /dev/null

rm -rf "${TMP_DIR}"
echo "✓ DMG created: ${DMG_PATH}"

CHECKSUM="$(shasum -a 256 "${DMG_PATH}" | awk '{print $1}')"
echo ""
echo "──────────────────────────────────────────────"
echo "  文件  ${DMG_NAME}"
echo "  版本  ${VERSION}"
echo "  SHA-256  ${CHECKSUM}"
echo "──────────────────────────────────────────────"
echo ""
echo "上传到 GitHub Releases 时，把以上 SHA-256 一并贴在 Release 说明里。"
