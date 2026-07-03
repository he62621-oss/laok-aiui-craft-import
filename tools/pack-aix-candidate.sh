#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_VALUE="${1:-0.2.0+codex.20260703}"
OUT_DIR="$ROOT_DIR/dist"
OUT_FILE="$OUT_DIR/laok-native-vision-agent.aix"
BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/laok-aiui-aix.XXXXXX")"
TOKEN_VALUE="${LAOK_BRIDGE_TOKEN:-}"
TOKEN_FILE="${LAOK_BRIDGE_TOKEN_FILE:-/Users/tony/.openclaw/secrets/rokid-laok-native-bridge-token}"

cleanup() {
  rm -rf "$BUILD_DIR"
}
trap cleanup EXIT

mkdir -p "$OUT_DIR"
rm -f "$OUT_FILE"
rsync -a --exclude-from="$ROOT_DIR/.aixignore" "$ROOT_DIR/" "$BUILD_DIR/"
printf '%s\n' "$VERSION_VALUE" > "$BUILD_DIR/VERSION"
if [[ -z "$TOKEN_VALUE" && -s "$TOKEN_FILE" ]]; then
  TOKEN_VALUE="$(tr -d '\r\n[:space:]' < "$TOKEN_FILE")"
fi
if [[ -n "$TOKEN_VALUE" ]]; then
  TOKEN_VALUE="$TOKEN_VALUE" /usr/bin/perl -0pi -e 's/__LAOK_BRIDGE_TOKEN__/$ENV{TOKEN_VALUE}/g' "$BUILD_DIR/pages/index/index.ink"
fi
find "$BUILD_DIR" -exec touch -t 202607030000 {} +

(
  cd "$BUILD_DIR"
  zip -Xqr "$OUT_FILE" .
)

printf '%s\n' "$OUT_FILE"
