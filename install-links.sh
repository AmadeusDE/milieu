#!/bin/sh
# install-links.sh: Create relative symlinks for all milieu tool packages

BIN_DIR="bin"
if [ ! -d "$BIN_DIR" ]; then
    echo "Error: bin directory not found. Run from project root."
    exit 1
fi

cd "$BIN_DIR" || exit
echo "--- Installing Relative Applet Links ---"

# 1. Install binutils binaries (Priority 0 - Absolute Lowest)
if [ -d "binutils-bin" ]; then
    echo "Installing binutils links..."
    for cmd_path in binutils-bin/*; do
        cmd=$(basename "$cmd_path")
        [ -n "$cmd" ] && [ ! -e "$cmd" ] && ln -s "$cmd_path" "$cmd"
    done
fi

# 2. Install mandoc binaries (Priority 1)
if [ -d "mandoc-bin" ]; then
    echo "Installing mandoc links (overriding binutils)..."
    for cmd_path in mandoc-bin/*; do
        cmd=$(basename "$cmd_path")
        [ -n "$cmd" ] && [ ! -e "$cmd" ] && ln -s "$cmd_path" "$cmd"
    done
fi

# 2. Install util-linux binaries (Priority 1)
if [ -d "util-linux-bin" ]; then
    echo "Installing util-linux links (overriding mandoc)..."
    for cmd_path in util-linux-bin/*; do
        cmd=$(basename "$cmd_path")
        [ -n "$cmd" ] && [ ! -e "$cmd" ] && ln -s "$cmd_path" "$cmd"
    done
fi

# 3. Install coreutils-box links (Priority 2)
if [ -f "coreutils-box" ]; then
    echo "Installing coreutils-box links (overriding util-linux)..."
    ./coreutils-box --help | sed -n '/Built-in programs:/,/^$/p' | sed 's/Built-in programs://' | tr ' ' '\n' | tr -d '[]' | grep '^[a-z]' | while read -r cmd; do
        [ -n "$cmd" ] && ln -sf coreutils-box "$cmd"
    done
fi

# 4. Install ubase-box links (Priority 3)
if [ -f "ubase-box" ]; then
    echo "Installing ubase-box links (overriding coreutils)..."
    ./ubase-box | tr ' ' '\n' | while read -r cmd; do
        [ -n "$cmd" ] && ln -sf ubase-box "$cmd"
    done
fi

# 5. Install sbase-box links (Priority 4)
if [ -f "sbase-box" ]; then
    echo "Installing sbase-box links (overriding ubase)..."
    ./sbase-box | tr ' ' '\n' | while read -r cmd; do
        [ -n "$cmd" ] && ln -sf sbase-box "$cmd"
    done
fi

# 6. Install Busybox links (Priority 5)
if [ -f "busybox" ]; then
    echo "Installing Busybox links (overriding Suckless)..."
    ./busybox --list | while read -r cmd; do
        [ -n "$cmd" ] && ln -sf busybox "$cmd"
    done
fi

# 7. Install Toybox links (Priority 6)
if [ -f "toybox" ]; then
    echo "Installing Toybox links (overriding busybox)..."
    for cmd in $(./toybox); do
        if [ "$cmd" != "toybox" ]; then
            ln -sf toybox "$cmd"
        fi
    done
fi

# 8. Install Dash links (Priority 7)
if [ -f "dash" ]; then
    echo "Installing dash links (overriding toybox)..."
    ln -sf dash sh
fi

# 8. Install Mksh links (Priority 7 - Highest)
if [ -f "mksh" ]; then
    echo "Installing mksh links (overriding everything else)..."
    ln -sf mksh ksh
fi

echo "Done."
