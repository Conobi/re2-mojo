#!/usr/bin/env bash
# Per-machine, one-shot install: build libre2_mojo.so via vendored RE2 + abseil.
# Idempotent — safe to rerun.
set -euo pipefail

echo "[re2-mojo install] 1/2 — pacman: cmake + git + build deps"
sudo pacman -S --needed cmake git pkgconf base-devel

echo "[re2-mojo install] 2/2 — build libre2_mojo.so"
bash "$(dirname "$0")/build.sh"

echo "OK: re2-mojo installed. lib/libre2_mojo.so is ready."
