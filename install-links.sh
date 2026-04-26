#!/bin/sh
# install-links.sh: Create relative symlinks for all milieu tool packages
# Priority (later overrides earlier):
# binutils < mandoc < util-linux < sbase < ubase < busybox < toybox < coreutils < shells
# Standalone binaries (like GNU sed/grep/tar/bash) are preserved and never overwritten by symlinks.

BIN_DIR="bin"
if [ ! -d "$BIN_DIR" ]; then
    echo "Error: bin directory not found. Run from project root."
    exit 1
fi

cd "$BIN_DIR" || exit
echo "--- Installing Relative Applet Links ---"

# Helper function to install a link only if it doesn't overwrite a real file
install_link() {
    target="$1"
    link_name="$2"
    # Skip if link_name is a real file
    [ -f "$link_name" ] && [ ! -L "$link_name" ] && return
    ln -sf "$target" "$link_name"
}

# 1. Install binutils binaries
if [ -d "binutils-bin" ]; then
    echo "Installing binutils links..."
    for cmd_path in binutils-bin/*; do
        cmd=$(basename "$cmd_path")
        [ -n "$cmd" ] && install_link "$cmd_path" "$cmd"
    done
fi

# 2. Install mandoc binaries
if [ -d "mandoc-bin" ]; then
    echo "Installing mandoc links..."
    for cmd_path in mandoc-bin/*; do
        cmd=$(basename "$cmd_path")
        [ -n "$cmd" ] && install_link "$cmd_path" "$cmd"
    done
fi

# 3. Install util-linux binaries
if [ -d "util-linux-bin" ]; then
    echo "Installing util-linux links..."
    for cmd_path in util-linux-bin/*; do
        cmd=$(basename "$cmd_path")
        [ -n "$cmd" ] && install_link "$cmd_path" "$cmd"
    done
fi

# 4. Install sbase-box links
if [ -f "sbase-box" ]; then
    echo "Installing sbase-box links..."
    ./sbase-box | tr ' ' '\n' | while read -r cmd; do
        [ -n "$cmd" ] && install_link sbase-box "$cmd"
    done
fi

# 5. Install ubase-box links
if [ -f "ubase-box" ]; then
    echo "Installing ubase-box links..."
    ./ubase-box | tr ' ' '\n' | while read -r cmd; do
        [ -n "$cmd" ] && install_link ubase-box "$cmd"
    done
fi

# 6. Install Busybox links
if [ -f "busybox" ]; then
    echo "Installing Busybox links..."
    ./busybox --list | while read -r cmd; do
        [ -n "$cmd" ] && [ "$cmd" != "busybox" ] && install_link busybox "$cmd"
    done
fi

# 7. Install Toybox links
if [ -f "toybox" ]; then
    echo "Installing Toybox links..."
    for cmd in $(./toybox); do
        # ! Exclude 'bash' and 'sh' from toybox links to avoid compatibility issues
        if [ "$cmd" != "toybox" ] && [ "$cmd" != "bash" ] && [ "$cmd" != "sh" ]; then
            install_link toybox "$cmd"
        fi
    done
fi

# 8. Install coreutils-box links (High Priority)
if [ -f "coreutils-box" ]; then
    echo "Installing coreutils-box links..."
    ./coreutils-box --help | sed -n '/Built-in programs:/,/^$/p' | sed 's/Built-in programs://' | tr ' ' '\n' | tr -d '[]' | grep '^[a-z]' > .coreutils.list
    while read -r cmd; do
        [ -n "$cmd" ] && install_link coreutils-box "$cmd"
    done < .coreutils.list
    rm -f .coreutils.list
fi

# 9. Shells (The ultimate authority)
if [ -f "dash" ]; then
    echo "Installing dash as sh..."
    install_link dash sh
fi

if [ -f "mksh" ]; then
    echo "Installing mksh as ksh..."
    install_link mksh ksh
fi

# ! Bash is now a real binary built in build.sh, so it will be protected by install_link helper.

# 10. Fix gmake/make link
if [ -f "gmake" ]; then
    install_link gmake make
fi

echo "Done."
