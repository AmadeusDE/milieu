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

# ! Isolate build environment from host system
echo "--- Setup Musl Toolchain ---"
if [ ! -f "$TOOLCHAIN_DIR/bin/x86_64-linux-musl-gcc" ]; then
    curl -L https://musl.cc/x86_64-linux-musl-cross.tgz -o "$CACHE_DIR/musl-cross.tgz"
    tar -xzf "$CACHE_DIR/musl-cross.tgz" -C "$TOOLCHAIN_DIR" --strip-components=1
fi
export PATH="$TOOLCHAIN_DIR/bin:/usr/bin:/bin"

echo "--- Building gmake Statically ---"
if [ ! -d "$SRC_ROOT/gmake" ]; then
    curl -L https://ftp.gnu.org/gnu/make/make-4.4.1.tar.gz -o "$CACHE_DIR/gmake.tar.gz"
    mkdir -p "$SRC_ROOT/gmake"
    tar -xzf "$CACHE_DIR/gmake.tar.gz" -C "$SRC_ROOT/gmake" --strip-components=1
fi
(
    cd "$SRC_ROOT/gmake" || exit
    echo "Configuring gmake..."
    ./configure CC="x86_64-linux-musl-gcc" \
                CFLAGS="-static" LDFLAGS="-static" \
                --host=x86_64-pc-linux-gnu \
                --disable-nls
    echo "Compiling gmake..."
    make "-j$(nproc)"
    rm -f "$BIN_DIR/gmake"
    cp make "$BIN_DIR/gmake"
    ln -sf gmake "$BIN_DIR/make"
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
    
    echo "Compiling toybox..."
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
    
    echo "Compiling busybox..."
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
"$BASE_DIR/install-links.sh"

echo "--- Building mksh Statically ---"
if [ ! -d "$SRC_ROOT/mksh" ]; then
    curl -L http://www.mirbsd.org/MirOS/dist/mir/mksh/mksh-R59c.tgz -o "$CACHE_DIR/mksh.tar.gz"
    mkdir -p "$SRC_ROOT/mksh"
    tar -xzf "$CACHE_DIR/mksh.tar.gz" -C "$SRC_ROOT/mksh" --strip-components=1
fi
(
    cd "$SRC_ROOT/mksh" || exit
    CC=x86_64-linux-musl-gcc LDFLAGS="-static" sh Build.sh
    rm -f "$BIN_DIR/mksh"
    cp mksh "$BIN_DIR/mksh"
)
"$BASE_DIR/install-links.sh"

# ! Activate bootstrapping phase 1: Basic shells
export PATH="$BIN_DIR:$TOOLCHAIN_DIR/bin:/usr/bin:/bin"
echo "--- PATH bootstrapping phase 1 activated: $PATH ---"

echo "--- Building GNU sed Statically ---"
if [ ! -d "$SRC_ROOT/sed" ]; then
    curl -L https://ftp.gnu.org/gnu/sed/sed-4.9.tar.xz -o "$CACHE_DIR/sed.tar.xz"
    mkdir -p "$SRC_ROOT/sed"
    tar -xJf "$CACHE_DIR/sed.tar.xz" -C "$SRC_ROOT/sed" --strip-components=1
fi
(
    cd "$SRC_ROOT/sed" || exit
    ./configure CC="x86_64-linux-musl-gcc" CFLAGS="-static" LDFLAGS="-static" \
                --host=x86_64-pc-linux-gnu \
                --disable-nls
    make "-j$(nproc)"
    rm -f "$BIN_DIR/sed"
    cp sed/sed "$BIN_DIR/sed"
)
"$BASE_DIR/install-links.sh"

echo "--- Building GNU grep Statically ---"
if [ ! -d "$SRC_ROOT/grep" ]; then
    curl -L https://ftp.gnu.org/gnu/grep/grep-3.11.tar.xz -o "$CACHE_DIR/grep.tar.xz"
    mkdir -p "$SRC_ROOT/grep"
    tar -xJf "$CACHE_DIR/grep.tar.xz" -C "$SRC_ROOT/grep" --strip-components=1
fi
(
    cd "$SRC_ROOT/grep" || exit
    ./configure CC="x86_64-linux-musl-gcc" CFLAGS="-static" LDFLAGS="-static" \
                --host=x86_64-pc-linux-gnu \
                --disable-nls
    make "-j$(nproc)"
    rm -f "$BIN_DIR/grep"
    cp src/grep "$BIN_DIR/grep"
)
"$BASE_DIR/install-links.sh"

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
"$BASE_DIR/install-links.sh"

echo "--- Building GNU tar Statically ---"
if [ ! -d "$SRC_ROOT/tar" ]; then
    curl -L https://ftp.gnu.org/gnu/tar/tar-1.35.tar.xz -o "$CACHE_DIR/tar.tar.xz"
    mkdir -p "$SRC_ROOT/tar"
    tar -xJf "$CACHE_DIR/tar.tar.xz" -C "$SRC_ROOT/tar" --strip-components=1
fi
(
    cd "$SRC_ROOT/tar" || exit
    ./configure CC="x86_64-linux-musl-gcc" CFLAGS="-static" LDFLAGS="-static" \
                --host=x86_64-pc-linux-gnu \
                --disable-nls
    make "-j$(nproc)"
    rm -f "$BIN_DIR/tar"
    cp src/tar "$BIN_DIR/tar"
)
"$BASE_DIR/install-links.sh"

echo "--- Building XZ Utils Statically ---"
if [ ! -d "$SRC_ROOT/xz" ]; then
    curl -L https://tukaani.org/xz/xz-5.8.3.tar.xz -o "$CACHE_DIR/xz.tar.xz"
    mkdir -p "$SRC_ROOT/xz"
    tar -xJf "$CACHE_DIR/xz.tar.xz" -C "$SRC_ROOT/xz" --strip-components=1
fi
(
    cd "$SRC_ROOT/xz" || exit
    ./configure CC="x86_64-linux-musl-gcc" CFLAGS="-static" LDFLAGS="-static" \
                --host=x86_64-pc-linux-gnu \
                --disable-shared \
                --enable-static \
                --disable-nls
    make "-j$(nproc)"
    rm -f "$BIN_DIR/xz"
    cp src/xz/xz "$BIN_DIR/xz"
)

echo "--- Building bzip2 Statically ---"
if [ ! -d "$SRC_ROOT/bzip2" ]; then
    curl -L https://sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz -o "$CACHE_DIR/bzip2.tar.gz"
    mkdir -p "$SRC_ROOT/bzip2"
    tar -xzf "$CACHE_DIR/bzip2.tar.gz" -C "$SRC_ROOT/bzip2" --strip-components=1
fi
(
    cd "$SRC_ROOT/bzip2" || exit
    # bzip2 doesn't use autoconf
    make CC="x86_64-linux-musl-gcc" CFLAGS="-static -O2" -j1
    rm -f "$BIN_DIR/bzip2"
    cp bzip2 "$BIN_DIR/bzip2"
)

echo "--- Building gzip Statically ---"
if [ ! -d "$SRC_ROOT/gzip" ]; then
    curl -L https://ftp.gnu.org/gnu/gzip/gzip-1.14.tar.xz -o "$CACHE_DIR/gzip.tar.xz"
    mkdir -p "$SRC_ROOT/gzip"
    tar -xJf "$CACHE_DIR/gzip.tar.xz" -C "$SRC_ROOT/gzip" --strip-components=1
fi
(
    cd "$SRC_ROOT/gzip" || exit
    ./configure CC="x86_64-linux-musl-gcc" CFLAGS="-static" LDFLAGS="-static" \
                --host=x86_64-pc-linux-gnu \
                --disable-nls
    make "-j$(nproc)"
    rm -f "$BIN_DIR/gzip"
    cp gzip "$BIN_DIR/gzip"
)

echo "--- Building GNU bash Statically ---"
if [ ! -d "$SRC_ROOT/bash" ]; then
    curl -L https://ftp.gnu.org/gnu/bash/bash-5.2.tar.gz -o "$CACHE_DIR/bash.tar.gz"
    mkdir -p "$SRC_ROOT/bash"
    tar -xzf "$CACHE_DIR/bash.tar.gz" -C "$SRC_ROOT/bash" --strip-components=1
fi
(
    cd "$SRC_ROOT/bash" || exit
    ./configure CC="x86_64-linux-musl-gcc" CFLAGS="-static -D_GNU_SOURCE" LDFLAGS="-static" \
                --host=x86_64-pc-linux-gnu \
                --without-bash-malloc \
                --disable-nls \
                bash_cv_func_strtoimax=no \
                bash_cv_func_strtoll=no \
                bash_cv_func_strtoull=no \
                bash_cv_func_strtoumax=no
    make "-j$(nproc)"
    rm -f "$BIN_DIR/bash"
    cp bash "$BIN_DIR/bash"
)
"$BASE_DIR/install-links.sh"

# ! Activate bootstrapping phase 2: Robust GNU tools
echo "--- PATH bootstrapping phase 2 activated (GNU tools prioritized) ---"

echo "--- Building sbase-box Statically ---"
if [ ! -d "$SRC_ROOT/sbase" ]; then
    git clone git://git.suckless.org/sbase "$SRC_ROOT/sbase"
fi
(
    cd "$SRC_ROOT/sbase" || exit
    # ! Original mkbox should work now that GNU sed is in PATH
    make CC="x86_64-linux-musl-gcc" CFLAGS="-static" LDFLAGS="-static" sbase-box -j1
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
    make CC="x86_64-linux-musl-gcc" CFLAGS="-static" LDFLAGS="-static" ubase-box -j1
    rm -f "$BIN_DIR/ubase-box"
    cp ubase-box "$BIN_DIR/ubase-box"
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


echo "--- Building ncurses Statically ---"
if [ ! -d "$SRC_ROOT/ncurses" ]; then
    curl -L https://ftp.gnu.org/pub/gnu/ncurses/ncurses-6.4.tar.gz -o "$CACHE_DIR/ncurses.tar.gz"
    mkdir -p "$SRC_ROOT/ncurses"
    tar -xzf "$CACHE_DIR/ncurses.tar.gz" -C "$SRC_ROOT/ncurses" --strip-components=1
fi
(
    cd "$SRC_ROOT/ncurses" || exit
    echo "Configuring ncurses..."
    CC="x86_64-linux-musl-gcc" CFLAGS="-static" LDFLAGS="-static" ./configure \
        --prefix="$BASE_DIR/ncurses-dist" \
        --with-termlib \
        --enable-widec \
        --without-shared \
        --enable-static \
        --without-ada \
        --without-tests \
        --without-debug \
        --without-manpages \
        --without-progs \
        --with-fallbacks=linux,screen,vt100,xterm,xterm-256color
    echo "Compiling ncurses..."
    make "-j$(nproc)"
    make install
    # Create compat symlinks so packages that look for -lncurses, -ltinfo, -lcurses find our widec libs
    cd "$BASE_DIR/ncurses-dist/lib" || exit
    ln -sf libncursesw.a libncurses.a
    ln -sf libtinfow.a   libtinfo.a
    ln -sf libncursesw.a libcurses.a
    # Symlink include dir so #include <ncurses.h> works from the plain include path
    cd "$BASE_DIR/ncurses-dist/include" || exit
    [ -e ncurses ] || ln -sf ncursesw ncurses
)

echo "--- Building less Statically ---"
if [ ! -d "$SRC_ROOT/less" ]; then
    curl -L https://www.greenwoodsoftware.com/less/less-692.tar.gz -o "$CACHE_DIR/less.tar.gz"
    mkdir -p "$SRC_ROOT/less"
    tar -xzf "$CACHE_DIR/less.tar.gz" -C "$SRC_ROOT/less" --strip-components=1
fi
(
    cd "$SRC_ROOT/less" || exit
    echo "Configuring less..."
    CC="x86_64-linux-musl-gcc" \
    CFLAGS="-static -I$BASE_DIR/ncurses-dist/include -I$BASE_DIR/ncurses-dist/include/ncursesw" \
    LDFLAGS="-static -L$BASE_DIR/ncurses-dist/lib" \
    LIBS="-lncurses -ltinfo" \
    ./configure --host=x86_64-pc-linux-gnu \
                --with-ospeed=15 \
                --with-editor=vi
    echo "Compiling less..."
    make "-j$(nproc)"
    rm -f "$BIN_DIR/less"
    cp less "$BIN_DIR/less"
)

echo "--- Building htop Statically ---"
if [ ! -d "$SRC_ROOT/htop" ]; then
    curl -L https://github.com/htop-dev/htop/archive/refs/tags/3.3.0.tar.gz -o "$CACHE_DIR/htop.tar.gz"
    mkdir -p "$SRC_ROOT/htop"
    tar -xzf "$CACHE_DIR/htop.tar.gz" -C "$SRC_ROOT/htop" --strip-components=1
fi
(
    cd "$SRC_ROOT/htop" || exit
    echo "Autogenerating htop build files..."
    ./autogen.sh
    echo "Configuring htop..."
    CC="x86_64-linux-musl-gcc" \
    CFLAGS="-static -I$BASE_DIR/ncurses-dist/include -I$BASE_DIR/ncurses-dist/include/ncursesw" \
    LDFLAGS="-static -L$BASE_DIR/ncurses-dist/lib" \
    LIBS="-lncurses -ltinfo" \
    ./configure --host=x86_64-pc-linux-gnu \
                --enable-static \
                --disable-unicode \
                --disable-shared
    echo "Compiling htop..."
    make "-j$(nproc)"
    rm -f "$BIN_DIR/htop"
    cp htop "$BIN_DIR/htop"
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
    fi

    # * Extract to a temporary folder in cache
    if [ ! -f "$CACHE_DIR/rust_tmp/install.sh" ]; then
        echo "--- Extracting Rust ---"
        mkdir -p "$CACHE_DIR/rust_tmp"
        tar -xf "$CACHE_DIR/rust.tar.xz" -C "$CACHE_DIR/rust_tmp" --strip-components=1
    fi

    # * Rust's installer script is actually very friendly to local dirs.
    # * We use --destdir and --prefix to install it into your local environment path.
    # * $BIN_DIR is usually inside a parent 'local' or 'env' folder. 
    # * We'll install to the parent of BIN_DIR so it populates bin/, lib/, and share/ correctly.
    ENV_ROOT=$(dirname "$BIN_DIR")
    
    bash "$CACHE_DIR/rust_tmp/install.sh" \
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
    tar -xjf "$CACHE_DIR/bootlin-gcc.tar.bz2" -C "$BASE_DIR/libexec/bootlin-gcc" --strip-components=1
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
        [ -f "binutils/$tool-new" ] && cp "binutils/$tool-new" "$BIN_DIR/binutils-bin/$tool"
    done

    [ -f "gas/as-new" ] && cp "gas/as-new" "$BIN_DIR/binutils-bin/as"
    [ -f "ld/ld-new" ] && cp "ld/ld-new" "$BIN_DIR/binutils-bin/ld"
    [ -f "gprof/gprof" ] && cp "gprof/gprof" "$BIN_DIR/binutils-bin/gprof"
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

echo "--- Installing Nix (Static, nix-portable) ---"
if [ ! -f "$BIN_DIR/nix" ]; then
    # * nix-portable: fully static nix bundle.
    # * NP_LOCATION is set in etc/profile to $MILIEU_DIR so the nix store lives
    # * at $MILIEU_DIR/.nix-portable instead of the default $HOME/.nix-portable.
    curl -L "https://github.com/davhau/nix-portable/releases/latest/download/nix-portable-x86_64" -o "$BIN_DIR/nix"
    chmod +x "$BIN_DIR/nix"
fi

echo "--- Installing Podman (Static, podman-static) ---"
PODMAN_LIBEXEC="$BASE_DIR/libexec/podman-static"
if [ ! -d "$PODMAN_LIBEXEC" ]; then
    curl -L "https://github.com/mgoltzsche/podman-static/releases/latest/download/podman-linux-amd64.tar.gz" \
         -o "$CACHE_DIR/podman-linux-amd64.tar.gz"

    # * Extract tarball (top-level dir stripped) — produces usr/ and etc/
    mkdir -p "$CACHE_DIR/podman-staging"
    tar -xzf "$CACHE_DIR/podman-linux-amd64.tar.gz" -C "$CACHE_DIR/podman-staging" --strip-components=1

    # * Copy only actual executables — bin/ and lib/podman/ contain binaries;
    # * share/ contains man pages and completion scripts which must be excluded.
    mkdir -p "$PODMAN_LIBEXEC/bin"
    for _dir in usr/local/bin usr/local/lib/podman usr/local/libexec/podman; do
        _src="$CACHE_DIR/podman-staging/$_dir"
        [ -d "$_src" ] || continue
        find "$_src" \( -type f -o -type l \) -exec cp -P {} "$PODMAN_LIBEXEC/bin/" \;
    done
    unset _dir _src

    # * Ship upstream registries / policy configs from the tarball
    mkdir -p "$BASE_DIR/etc/containers"
    cp -r "$CACHE_DIR/podman-staging/etc/containers/." "$BASE_DIR/etc/containers/"

    rm -rf "$CACHE_DIR/podman-staging"
fi

# * Generate containers.conf from the committed template (substitutes @MILIEU_DIR@)
# * The template lives in etc/containers/containers.conf.in
sed "s|@MILIEU_DIR@|$BASE_DIR|g" \
    "$BASE_DIR/etc/containers/containers.conf.in" \
    > "$BASE_DIR/etc/containers/containers.conf"

echo "--- Installing distrobox ---"
if [ ! -f "$BIN_DIR/distrobox" ]; then
    # * distrobox is a set of shell scripts; --prefix installs them to bin/
    curl -L https://raw.githubusercontent.com/89luca89/distrobox/main/install \
         -o "$CACHE_DIR/distrobox-install"
    chmod +x "$CACHE_DIR/distrobox-install"
    # ! BASE_DIR used as prefix: scripts land in $BASE_DIR/bin/distrobox*
    "$CACHE_DIR/distrobox-install" --prefix "$BASE_DIR"
fi

# * Copy podman wrapper + create docker compat symlink
cp "$BASE_DIR/script/podman" "$BIN_DIR/podman"
chmod +x "$BIN_DIR/podman"
ln -sf podman "$BIN_DIR/docker"

echo "--- First-launch setup configured (tools will be installed on launch via milieu-sync) ---"

echo "--- Finalizing and Cleanup ---"
rm -rf "$BASE_DIR/zlib-dist" "$BASE_DIR/ncurses-dist"
# * Strip debug info from single-binary tools to reduce size
x86_64-linux-musl-strip "$BIN_DIR/htop" "$BIN_DIR/btop" "$BIN_DIR/less" 2>/dev/null || true
# * Safely chmod only actual files in BIN_DIR to avoid dangling symlink errors
find "$BIN_DIR" -maxdepth 1 -type f -exec chmod +x {} +
echo "Build complete."
ls -l "$BIN_DIR"