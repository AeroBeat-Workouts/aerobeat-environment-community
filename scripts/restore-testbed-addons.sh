#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TESTBED_DIR="$ROOT_DIR/.testbed"
ADDONS_DIR="$TESTBED_DIR/addons"
CACHE_DIR="$TESTBED_DIR/.addons"

if [[ ! -d "$TESTBED_DIR" ]]; then
  echo "Expected testbed at $TESTBED_DIR" >&2
  exit 1
fi

mkdir -p "$ADDONS_DIR"
find "$ADDONS_DIR" -mindepth 1 -maxdepth 1 ! -name '.editorconfig' -exec rm -rf {} +
rm -rf "$CACHE_DIR"

cd "$TESTBED_DIR"
godotenv addons install

echo "Restored GodotEnv addons into $ADDONS_DIR"
