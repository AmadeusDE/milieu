#!/bin/sh
set -e

# * build.sh: Refactored with a clean directory structure (src/ component-name)
BASE_DIR=$(pwd)
BIN_DIR="$BASE_DIR/bin"
TOOLCHAIN_DIR="$BASE_DIR/toolchain"
CONFIG_DIR="$BASE_DIR/configs"
SRC_ROOT="$BASE_DIR/src"
CACHE_DIR="$SRC_ROOT/cache"
MILIEU_DIR="$(pwd)"
export MILIEU_DIR

mkdir -p "$BIN_DIR" "$TOOLCHAIN_DIR" "$CONFIG_DIR" "$SRC_ROOT" "$CACHE_DIR" etc

echo "--- Setup Musl Toolchain ---"
if [ ! -f "$TOOLCHAIN_DIR/bin/x86_64-linux-musl-gcc" ]; then
    curl -L https://musl.cc/x86_64-linux-musl-cross.tgz -o "$CACHE_DIR/musl-cross.tgz"
    tar -xzf "$CACHE_DIR/musl-cross.tgz" -C "$TOOLCHAIN_DIR" --strip-components=1
fi
# export PATH="$BIN_DIR:$TOOLCHAIN_DIR/bin:$PATH"
export PATH="$TOOLCHAIN_DIR/bin:$PATH"

echo "--- Building gmake Statically ---"
if [ ! -d "$SRC_ROOT/gmake" ]; then
    curl -L https://ftp.gnu.org/gnu/make/make-4.4.1.tar.gz -o "$CACHE_DIR/gmake.tar.gz"
    mkdir -p "$SRC_ROOT/gmake"
    tar -xzf "$CACHE_DIR/gmake.tar.gz" -C "$SRC_ROOT/gmake" --strip-components=1
fi
(
    cd "$SRC_ROOT/gmake" || exit
    ./configure CC="x86_64-linux-musl-gcc" \
                CFLAGS="-static" LDFLAGS="-static" \
                --host=x86_64-pc-linux-gnu \
                --disable-nls
    make "-j$(nproc)"
    rm -f "$BIN_DIR/gmake"
    cp make "$BIN_DIR/gmake"
    ln -s "$BIN_DIR/gmake" "$BIN_DIR/make"
)

echo "--- Building toybox from source ---"
if [ ! -d "$SRC_ROOT/toybox" ]; then
    curl -L https://github.com/landley/toybox/archive/refs/tags/0.8.11.tar.gz -o "$CACHE_DIR/toybox.tar.gz"
    mkdir -p "$SRC_ROOT/toybox"
    tar -xzf "$CACHE_DIR/toybox.tar.gz" -C "$SRC_ROOT/toybox" --strip-components=1
fi
(
    cd "$SRC_ROOT/toybox" || exit
    if [ -s "$CONFIG_DIR/toybox.config" ]; then
        echo "Using existing toybox config..."
        cp "$CONFIG_DIR/toybox.config" .config
    else
        echo "Generating default toybox config..."
        make defconfig
    fi
    
    # ! Enforce mandatory settings for milieu
    echo "Enforcing milieu requirements in toybox config..."
    sed -i 's/# CONFIG_VI is not set/CONFIG_VI=y/' .config || true
    sed -i 's/CONFIG_VI=n/CONFIG_VI=y/' .config || true
    sed -i 's/# CONFIG_TOYBOX_PENDING is not set/CONFIG_TOYBOX_PENDING=y/' .config || true
    sed -i 's/CONFIG_TOYBOX_FORCE_NOMMU=y/CONFIG_TOYBOX_FORCE_NOMMU=n/' .config || true
    grep -q "CONFIG_TOYBOX_STATIC=y" .config || echo "CONFIG_TOYBOX_STATIC=y" >> .config
    
    make CC=x86_64-linux-musl-gcc CFLAGS="--static" LDFLAGS="--static"
    rm -f "$BIN_DIR/toybox"
    cp toybox "$BIN_DIR/toybox"
    cp .config "$CONFIG_DIR/toybox.config"
)
"$BASE_DIR/install-links.sh"

echo "--- Building busybox from source ---"
if [ ! -d "$SRC_ROOT/busybox" ]; then
    curl -L https://busybox.net/downloads/busybox-1.36.1.tar.bz2 -o "$CACHE_DIR/busybox.tar.bz2"
    mkdir -p "$SRC_ROOT/busybox"
    tar -xjf "$CACHE_DIR/busybox.tar.bz2" -C "$SRC_ROOT/busybox" --strip-components=1
fi
(
    cd "$SRC_ROOT/busybox" || exit
    if [ -s "$CONFIG_DIR/busybox.config" ]; then
        echo "Using existing busybox config..."
        cp "$CONFIG_DIR/busybox.config" .config
    else
        echo "Generating default busybox config..."
        make defconfig
    fi
    
    # ! Enforce mandatory settings for milieu
    echo "Enforcing milieu requirements in busybox config..."
    sed -i 's/^# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config
    sed -i 's/^CONFIG_STATIC=n/CONFIG_STATIC=y/' .config || true
    
    # * Sync config
    make oldconfig CC=x86_64-linux-musl-gcc HOSTCC=gcc < /dev/null || make olddefconfig CC=x86_64-linux-musl-gcc HOSTCC=gcc
    
    make CC=x86_64-linux-musl-gcc HOSTCC=gcc CFLAGS="--static" LDFLAGS="--static" "-j$(nproc)"
    rm -f "$BIN_DIR/busybox"
    cp busybox "$BIN_DIR/busybox"
    cp .config "$CONFIG_DIR/busybox.config"
)
"$BASE_DIR/install-links.sh"

echo "--- Building dash Statically ---"
if [ ! -d "$SRC_ROOT/dash" ]; then
    curl -L http://gondor.apana.org.au/~herbert/dash/files/dash-0.5.12.tar.gz -o "$CACHE_DIR/dash.tar.gz"
    mkdir -p "$SRC_ROOT/dash"
    tar -xzf "$CACHE_DIR/dash.tar.gz" -C "$SRC_ROOT/dash" --strip-components=1
fi
(
    cd "$SRC_ROOT/dash" || exit
    if [ ! -f src/mksyntax ]; then
        ./configure
        make -C src mksyntax mknodes mkinit mksignames CC=gcc
    fi
    ./configure CC="x86_64-linux-musl-gcc" --host=x86_64-pc-linux-gnu CFLAGS="-static" LDFLAGS="-static"
    touch src/mksyntax src/mknodes src/mkinit src/mksignames
    make "-j$(nproc)"
    rm -f "$BIN_DIR/dash"
    cp src/dash "$BIN_DIR/dash"
)

echo "--- Building mksh Statically ---"
if [ ! -d "$SRC_ROOT/mksh" ]; then
    curl -L http://www.mirbsd.org/MirOS/dist/mir/mksh/mksh-R59c.tgz -o "$CACHE_DIR/mksh.tgz"
    mkdir -p "$SRC_ROOT/mksh"
    tar -xzf "$CACHE_DIR/mksh.tgz" -C "$SRC_ROOT/mksh" --strip-components=1
fi
(
    cd "$SRC_ROOT/mksh" || exit
    CC="x86_64-linux-musl-gcc" LDFLAGS="-static" dash Build.sh -r
    rm -f "$BIN_DIR/mksh"
    cp mksh "$BIN_DIR/mksh"
)

echo "--- Building sbase-box Statically ---"
if [ ! -d "$SRC_ROOT/sbase" ]; then
    git clone git://git.suckless.org/sbase "$SRC_ROOT/sbase"
fi
(
    cd "$SRC_ROOT/sbase" || exit
    mkdir -p build
    PATH="/usr/bin:/bin:$PATH" make CC="x86_64-linux-musl-gcc" CFLAGS="-static" LDFLAGS="-static" sbase-box -j1
    rm -f "$BIN_DIR/sbase-box"
    cp sbase-box "$BIN_DIR/sbase-box"
)

echo "--- Building ubase-box Statically ---"
if [ ! -d "$SRC_ROOT/ubase" ]; then
    git clone git://git.suckless.org/ubase "$SRC_ROOT/ubase"
fi
(
    cd "$SRC_ROOT/ubase" || exit
    mkdir -p build
    PATH="/usr/bin:/bin:$PATH" make CC="x86_64-linux-musl-gcc" CFLAGS="-static" LDFLAGS="-static" ubase-box -j1
    rm -f "$BIN_DIR/ubase-box"
    cp ubase-box "$BIN_DIR/ubase-box"
)

echo "--- Building GNU Coreutils Statically ---"
if [ ! -d "$SRC_ROOT/coreutils" ]; then
    curl -L https://ftp.gnu.org/gnu/coreutils/coreutils-9.5.tar.xz -o "$CACHE_DIR/coreutils.tar.xz"
    mkdir -p "$SRC_ROOT/coreutils"
    tar -xJf "$CACHE_DIR/coreutils.tar.xz" -C "$SRC_ROOT/coreutils" --strip-components=1
fi
(
    cd "$SRC_ROOT/coreutils" || exit
    ./configure CC="x86_64-linux-musl-gcc" CFLAGS="-static" LDFLAGS="-static" \
                --host=x86_64-pc-linux-gnu \
                --enable-single-binary=symlinks \
                --disable-nls \
                --without-selinux
    make "-j$(nproc)"
    rm -f "$BIN_DIR/coreutils-box"
    cp src/coreutils "$BIN_DIR/coreutils-box"
)

echo "--- Building util-linux Statically ---"
UTIL_LINUX_TAR="$CACHE_DIR/util-linux.tar.xz"
if [ ! -f "$UTIL_LINUX_TAR" ]; then
    curl -L https://mirrors.edge.kernel.org/pub/linux/utils/util-linux/v2.40/util-linux-2.40.tar.xz -o "$UTIL_LINUX_TAR"
fi

if [ ! -d "$SRC_ROOT/util-linux" ]; then
    mkdir -p "$SRC_ROOT/util-linux"
    tar -xJf "$UTIL_LINUX_TAR" -C "$SRC_ROOT/util-linux" --strip-components=1
fi
(
    cd "$SRC_ROOT/util-linux" || exit
    # ! Reset source tree via re-extraction to avoid config errors from previous attempts
    cd "$SRC_ROOT" || exit
    rm -rf util-linux
    mkdir -p util-linux
    tar -xJf "$UTIL_LINUX_TAR" -C util-linux --strip-components=1
    cd util-linux || exit

    ./configure CC="x86_64-linux-musl-gcc" CFLAGS="-static" LDFLAGS="-static" \
                --host=x86_64-pc-linux-gnu \
                --disable-shared \
                --enable-static \
                --disable-nls \
                --without-ncurses \
                --without-ncursesw \
                --without-tinfo \
                --without-readline \
                --without-cap-ng \
                --without-libmagic \
                --without-udev \
                --without-systemd \
                --disable-asciidoc \
                --disable-gtk-doc \
                --disable-pg \
                --disable-more \
                --disable-setterm \
                --disable-ul \
                --disable-lslogins \
                --disable-liblastlog2 \
                --disable-pylibmount \
                --disable-makeinstall-chown
    make "-j$(nproc)"
    
    # * Use make install with DESTDIR to get all binaries correctly organized
    echo "--- Installing util-linux binaries to temporary prefix ---"
    rm -rf "$BASE_DIR/util-linux-dist"
    make install DESTDIR="$BASE_DIR/util-linux-dist"
    
    mkdir -p "$BIN_DIR/util-linux-bin"
    # * Copy from all common binary locations in the dist folder
    find "$BASE_DIR/util-linux-dist" -type f -executable \( -path "*/bin/*" -o -path "*/sbin/*" \) -exec cp {} "$BIN_DIR/util-linux-bin/" \;
    rm -rf "$BASE_DIR/util-linux-dist"
)

echo "--- Building zlib Statically ---"
if [ ! -d "$SRC_ROOT/zlib" ]; then
    curl -L https://github.com/madler/zlib/archive/refs/tags/v1.3.1.tar.gz -o "$CACHE_DIR/zlib.tar.gz"
    mkdir -p "$SRC_ROOT/zlib"
    tar -xzf "$CACHE_DIR/zlib.tar.gz" -C "$SRC_ROOT/zlib" --strip-components=1
fi
(
    cd "$SRC_ROOT/zlib" || exit
    CC="x86_64-linux-musl-gcc" CFLAGS="-static" LDFLAGS="-static" ./configure --static --prefix="$BASE_DIR/zlib-dist"
    make "-j$(nproc)"
    make install
)

echo "--- Building mandoc Statically ---"
if [ ! -d "$SRC_ROOT/mandoc" ]; then
    curl -L https://mandoc.bsd.lv/snapshots/mandoc-1.14.6.tar.gz -o "$CACHE_DIR/mandoc.tar.gz"
    mkdir -p "$SRC_ROOT/mandoc"
    tar -xzf "$CACHE_DIR/mandoc.tar.gz" -C "$SRC_ROOT/mandoc" --strip-components=1
fi
(
    cd "$SRC_ROOT/mandoc" || exit
    # * Create configure.local for static musl build, pointing to our zlib
    cat <<EOF > configure.local
CC=x86_64-linux-musl-gcc
CFLAGS="-static -I$BASE_DIR/zlib-dist/include"
LDFLAGS="-static -L$BASE_DIR/zlib-dist/lib"
PREFIX=/usr
MANDIR=/usr/share/man
EOF
    ./configure
    make "-j$(nproc)"

    mkdir -p "$BIN_DIR/mandoc-bin"
    cp mandoc demandoc soelim "$BIN_DIR/mandoc-bin/"

    # * Create symlinks for unified tools
    (
        cd "$BIN_DIR/mandoc-bin" || exit
        ln -sf mandoc man
        ln -sf mandoc apropos
        ln -sf mandoc whatis
        ln -sf mandoc makewhatis
        ln -sf mandoc tbl
    )
)

echo "--- Installing pfetch ---"
curl -L https://raw.githubusercontent.com/dylanaraps/pfetch/master/pfetch -o "$BIN_DIR/pfetch"

echo "--- Installing fastfetch ---"
if [ ! -f "$BIN_DIR/fastfetch" ]; then
    curl -L "https://github.com/fastfetch-cli/fastfetch/releases/download/2.61.0/fastfetch-linux-amd64.tar.gz" \
         -o "$CACHE_DIR/fastfetch.tar.gz"

    # * Extract everything
    tar -xzf "$CACHE_DIR/fastfetch.tar.gz" -C "$CACHE_DIR"

    # * Specifically look for the binary in the usr/bin path within the extracted folder
    # * This avoids the bash-completion file located in the shell/ completions folder
    find "$CACHE_DIR" -path "*/usr/bin/fastfetch" -type f -exec cp {} "$BIN_DIR/fastfetch" \;
    find "$CACHE_DIR" -path "*/usr/bin/flashfetch" -type f -exec cp {} "$BIN_DIR/flashfetch" \;
fi

echo "--- Installing Rust ---"

RUST_VERSION="1.95.0"
RUST_ARCH="x86_64-unknown-linux-gnu"

if [ ! -f "$BIN_DIR/rustc" ]; then
    # * Download the standalone 'combined' installer
    # * This includes cargo, rustc, and std for the musl target
    if [ ! -f "$CACHE_DIR/rust.tar.xz" ]; then
        curl -L "https://static.rust-lang.org/dist/rust-${RUST_VERSION}-${RUST_ARCH}.tar.xz" \
           -o "$CACHE_DIR/rust.tar.xz"

        # * Extract to a temporary folder in cache
        mkdir -p "$CACHE_DIR/rust_tmp"
        PATH="/usr/bin:/bin:/usr/local/bin:$PATH" tar -xf "$CACHE_DIR/rust.tar.xz" -C "$CACHE_DIR/rust_tmp" --strip-components=1
    fi

    # * Rust's installer script is actually very friendly to local dirs.
    # * We use --destdir and --prefix to install it into your local environment path.
    # * $BIN_DIR is usually inside a parent 'local' or 'env' folder. 
    # * We'll install to the parent of BIN_DIR so it populates bin/, lib/, and share/ correctly.
    ENV_ROOT=$(dirname "$BIN_DIR")
    
    PATH="/usr/bin:/bin:/usr/local/bin:$PATH" bash "$CACHE_DIR/rust_tmp/install.sh" \
        --destdir="$ENV_ROOT" \
        --prefix="" \
        --disable-ldconfig

    # * Cleanup
    #rm -rf "$CACHE_DIR/rust_tmp"
    
    echo "Rust installed to $ENV_ROOT"
fi

echo "--- Installing GCC (glibc) toolchain ---"
# * We need a glibc-targeted GCC so Rust and other tools work correctly on glibc hosts (like SteamOS).
# * We install this into libexec/ so it gets packaged by package.sh for the final milieu environment.
if [ ! -d "$BASE_DIR/libexec/bootlin-gcc" ]; then
    curl -L https://toolchains.bootlin.com/downloads/releases/toolchains/x86-64/tarballs/x86-64--glibc--stable-2024.02-1.tar.bz2 -o "$CACHE_DIR/bootlin-gcc.tar.bz2"
    mkdir -p "$BASE_DIR/libexec/bootlin-gcc"
    PATH="/usr/bin:/bin:$PATH" tar -xjf "$CACHE_DIR/bootlin-gcc.tar.bz2" -C "$BASE_DIR/libexec/bootlin-gcc" --strip-components=1
fi

echo "--- Installing Go toolchain ---"
if [ ! -d "$SRC_ROOT/go-dist" ]; then
    curl -L https://go.dev/dl/go1.26.2.linux-amd64.tar.gz -o "$CACHE_DIR/go.tar.gz"
    mkdir -p "$SRC_ROOT/go-dist"
    tar -xzf "$CACHE_DIR/go.tar.gz" -C "$SRC_ROOT/go-dist" --strip-components=1
fi
# * Symlink go and gofmt into bin so they appear on PATH
ln -sf "../src/go-dist/bin/go"    "$BIN_DIR/go"
ln -sf "../src/go-dist/bin/gofmt" "$BIN_DIR/gofmt"

echo "--- Building binutils Statically ---"
if [ ! -d "$SRC_ROOT/binutils" ]; then
    curl -L https://ftp.gnu.org/gnu/binutils/binutils-2.42.tar.xz -o "$CACHE_DIR/binutils.tar.xz"
    mkdir -p "$SRC_ROOT/binutils"
    tar -xJf "$CACHE_DIR/binutils.tar.xz" -C "$SRC_ROOT/binutils" --strip-components=1
fi
(
    cd "$SRC_ROOT/binutils" || exit
    ./configure CC="x86_64-linux-musl-gcc" \
                CFLAGS="-static" LDFLAGS="-static" \
                --host=x86_64-pc-linux-musl \
                --target=x86_64-pc-linux-gnu \
                --disable-shared \
                --enable-static \
                --disable-nls \
                --disable-gdb \
                --disable-gprofng \
                --disable-libdecnumber \
                --disable-readline \
                --disable-sim \
                --with-static-standard-libraries
    make "-j$(nproc)"
    mkdir -p "$BIN_DIR/binutils-bin"
    for tool in ar nm objcopy objdump ranlib readelf size strings strip addr2line; do
        [ -f "binutils/$tool" ] && cp "binutils/$tool" "$BIN_DIR/binutils-bin/"
    done

    [ -f "gas/as-new" ] && cp "gas/as-new" "$BIN_DIR/binutils-bin/as"
    [ -f "ld/ld-new" ] && cp "ld/ld-new" "$BIN_DIR/binutils-bin/ld"
    [ -f "gprof/gprof" ] && cp "gprof/gprof" "$BIN_DIR/binutils-bin/gprof"
    
    # * Copy all produced executables in one pass
    find . -maxdepth 2 -type f -perm /111 \
        \( -name "ar" -o -name "as" -o -name "ld" -o -name "ld.bfd" \
        -o -name "nm" -o -name "objcopy" -o -name "objdump" \
        -o -name "ranlib" -o -name "readelf" -o -name "size" \
        -o -name "strings" -o -name "strip" -o -name "addr2line" \
        -o -name "gprof" \) \
        -exec cp {} "$BIN_DIR/binutils-bin/" \;
)

echo "--- Building btop Statically ---"
if [ ! -d "$SRC_ROOT/btop" ]; then
    curl -L https://github.com/aristocratos/btop/archive/refs/tags/v1.3.2.tar.gz -o "$CACHE_DIR/btop.tar.gz"
    mkdir -p "$SRC_ROOT/btop"
    tar -xzf "$CACHE_DIR/btop.tar.gz" -C "$SRC_ROOT/btop" --strip-components=1
fi
(
    cd "$SRC_ROOT/btop" || exit
    # * btop has a built-in STATIC=true flag that handles all static linking flags correctly
    make STATIC=true \
         CXX="x86_64-linux-musl-g++" \
         AR="x86_64-linux-musl-ar" \
         RANLIB="x86_64-linux-musl-ranlib" \
         "-j$(nproc)"
    rm -f "$BIN_DIR/btop"
    cp bin/btop "$BIN_DIR/btop"
)

./install-links.sh

echo "--- Installing micro ---"

#curl https://getmic.ro | bash

#mv micro bin/

echo "--- Installing Scriptlets ---"
cp script/* bin/

echo "--- Installing cargo-binstall ---"
if [ ! -f "$BIN_DIR/cargo-binstall" ]; then
    curl -L https://github.com/cargo-bins/cargo-binstall/releases/latest/download/cargo-binstall-x86_64-unknown-linux-musl.tgz -o "$CACHE_DIR/cargo-binstall.tgz"
    tar -xzf "$CACHE_DIR/cargo-binstall.tgz" -C "$BIN_DIR" cargo-binstall
fi

echo "--- First-launch setup configured (tools will be installed on launch via milieu-sync) ---"

echo "--- Finalizing and Cleanup ---"
rm -rf "$BASE_DIR/zlib-dist" "$BASE_DIR/ncurses-dist"
# * Strip debug info from single-binary tools to reduce size
x86_64-linux-musl-strip "$BIN_DIR/htop" "$BIN_DIR/btop" 2>/dev/null || true
# * Safely chmod only actual files in BIN_DIR to avoid dangling symlink errors
find "$BIN_DIR" -maxdepth 1 -type f -exec chmod +x {} +
echo "Build complete."
ls -l "$BIN_DIR"