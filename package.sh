#!/bin/sh
# package.sh: Bundle milieu into portable tarballs.
#   milieu-<date>.tar.gz      — binary package (bin/, etc/, launchers)
#   milieu-<date>-src.tar.gz  — source package (scripts and configs to rebuild)

set -e

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
VERSION="$(date +%Y%m%d)"
BIN_OUT="$BASE_DIR/milieu-$VERSION.tar.gz"
SRC_OUT="$BASE_DIR/milieu-$VERSION-src.tar.gz"

echo "--- Packaging milieu ($VERSION) ---"

# Binary package
echo "Building binary package..."
tar -czf "$BIN_OUT" \
    --exclude="$BASE_DIR/bin/util-linux-bin/*.py" \
    -C "$BASE_DIR" \
    bin \
    etc \
    lib \
    libexec \
    share \
    usr \
    milieu-sh \
    milieu-sh-sys \
    milieu-sh-overlay
echo "  $(du -sh "$BIN_OUT" | cut -f1)  $BIN_OUT"

# Source package
echo "Building source package..."
tar -czf "$SRC_OUT" \
    -C "$BASE_DIR" \
    configs \
    etc \
    script \
    build.sh \
    install-links.sh \
    milieu-sh \
    milieu-sh-overlay \
    milieu-sh-sys \
    package.sh
echo "  $(du -sh "$SRC_OUT" | cut -f1)  $SRC_OUT"

echo "Done."
