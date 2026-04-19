#!/bin/sh
# package.sh: Bundle milieu into a portable tarball.
# Packages bin/, etc/, the milieu-sh launchers, and install-links.sh.
# The tarball is self-contained and relocatable — unpack anywhere and run.

set -e

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
VERSION="$(date +%Y%m%d)"
OUT="$BASE_DIR/milieu-$VERSION.tar.gz"

echo "--- Packaging milieu ($VERSION) ---"

tar -czf "$OUT" \
    --exclude="$BASE_DIR/bin/util-linux-bin/*.py" \
    -C "$BASE_DIR" \
    bin \
    etc \
    milieu-sh \
    milieu-sh-sys \
    milieu-sh-overlay

SIZE=$(du -sh "$OUT" | cut -f1)
echo "Done: $OUT ($SIZE)"
