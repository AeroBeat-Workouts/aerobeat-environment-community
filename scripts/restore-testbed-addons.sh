#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
find .testbed/addons -mindepth 1 -maxdepth 1 ! -name .editorconfig -exec rm -rf {} +
rm -rf .testbed/.addons .testbed/.godot
cd .testbed
godotenv addons install
