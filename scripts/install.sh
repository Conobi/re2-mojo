#!/usr/bin/env bash
# Per-machine, one-shot install: RE2 + cre2.
# Idempotent — safe to rerun (e.g. after `pacman -Syu` bumps re2's SONAME).
set -euo pipefail

echo "[re2-mojo install] 1/3 — pacman: re2 + abseil-cpp + build deps"
sudo pacman -S --needed re2 abseil-cpp cmake pkgconf base-devel

echo "[re2-mojo install] 2/3 — cre2: clone + autotools build + install"
BUILD_DIR=$(mktemp -d)
trap 'rm -rf "$BUILD_DIR"' EXIT
git clone --depth 1 https://github.com/marcomaggi/cre2.git "$BUILD_DIR"
cd "$BUILD_DIR"
sh autogen.sh
./configure --prefix=/usr/local
make -j"$(nproc)"
sudo make install
sudo ldconfig

echo "[re2-mojo install] 3/3 — sanity check"
if ldconfig -p | grep -q libcre2; then
  echo "OK: libcre2 installed."
  pkg-config --modversion cre2 2>/dev/null && true
else
  echo "ERROR: libcre2 not found after install"
  exit 1
fi
