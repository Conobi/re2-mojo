#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SHIM_DIR="$REPO_ROOT/cpp/libre2-mojo"
LIB_DIR="$REPO_ROOT/lib"

# Default generator (Make or Ninja) is single-config; output lands at
# build root. Multi-config generators (Xcode, MSVC) are out of scope.
cmake -S "$SHIM_DIR" -B "$SHIM_DIR/build" -DCMAKE_BUILD_TYPE=Release
cmake --build "$SHIM_DIR/build" -j"$(nproc)"

mkdir -p "$LIB_DIR"
cp "$SHIM_DIR/build/libre2_mojo.so" "$LIB_DIR/libre2_mojo.so"
echo "OK: built $LIB_DIR/libre2_mojo.so"
