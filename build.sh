#!/bin/sh
set -e

# build.sh: Refactored with a clean directory structure (src/ component-name)
BASE_DIR=$(pwd)
BIN_DIR="$BASE_DIR/bin"
TOOLCHAIN_DIR="$BASE_DIR/toolchain"
CONFIG_DIR="$BASE_DIR/configs"
SRC_ROOT="$BASE_DIR/src"
CACHE_DIR="$SRC_ROOT/cache"

mkdir -p "$BIN_DIR" "$TOOLCHAIN_DIR" "$CONFIG_DIR" "$SRC_ROOT" "$CACHE_DIR" etc

echo "--- Setup Musl Toolchain ---"
if [ ! -f "$TOOLCHAIN_DIR/bin/x86_64-linux-musl-gcc" ]; then
    curl -L https://musl.cc/x86_64-linux-musl-cross.tgz -o "$CACHE_DIR/musl-cross.tgz"
    tar -xzf "$CACHE_DIR/musl-cross.tgz" -C "$TOOLCHAIN_DIR" --strip-components=1
fi
export PATH="$TOOLCHAIN_DIR/bin:$PATH"

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
    
    # Enforce mandatory settings for milieu
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
    
    # Enforce mandatory settings for milieu
    echo "Enforcing milieu requirements in busybox config..."
    sed -i 's/^# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config
    sed -i 's/^CONFIG_STATIC=n/CONFIG_STATIC=y/' .config || true
    
    # Sync config
    make oldconfig CC=x86_64-linux-musl-gcc HOSTCC=gcc < /dev/null || make olddefconfig CC=x86_64-linux-musl-gcc HOSTCC=gcc
    
    make CC=x86_64-linux-musl-gcc HOSTCC=gcc CFLAGS="--static" LDFLAGS="--static" "-j$(nproc)"
    rm -f "$BIN_DIR/busybox"
    cp busybox "$BIN_DIR/busybox"
    cp .config "$CONFIG_DIR/busybox.config"
)

echo "--- Building mksh Statically ---"
if [ ! -d "$SRC_ROOT/mksh" ]; then
    curl -L http://www.mirbsd.org/MirOS/dist/mir/mksh/mksh-R59c.tgz -o "$CACHE_DIR/mksh.tgz"
    mkdir -p "$SRC_ROOT/mksh"
    tar -xzf "$CACHE_DIR/mksh.tgz" -C "$SRC_ROOT/mksh" --strip-components=1
fi
(
    cd "$SRC_ROOT/mksh" || exit
    CC="x86_64-linux-musl-gcc" LDFLAGS="-static" sh Build.sh -r
    rm -f "$BIN_DIR/mksh"
    cp mksh "$BIN_DIR/mksh"
)

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

echo "--- Building sbase-box Statically ---"
if [ ! -d "$SRC_ROOT/sbase" ]; then
    git clone git://git.suckless.org/sbase "$SRC_ROOT/sbase"
fi
(
    cd "$SRC_ROOT/sbase" || exit
    make CC="x86_64-linux-musl-gcc" CFLAGS="-static" LDFLAGS="-static" sbase-box "-j$(nproc)"
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
    make CC="x86_64-linux-musl-gcc" CFLAGS="-static" LDFLAGS="-static" ubase-box "-j$(nproc)"
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
    # Reset source tree via re-extraction to avoid config errors from previous attempts
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
    
    # Use make install with DESTDIR to get all binaries correctly organized
    echo "--- Installing util-linux binaries to temporary prefix ---"
    rm -rf "$BASE_DIR/util-linux-dist"
    make install DESTDIR="$BASE_DIR/util-linux-dist"
    
    mkdir -p "$BIN_DIR/util-linux-bin"
    # Copy from all common binary locations in the dist folder
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
    # Create configure.local for static musl build, pointing to our zlib
    cat <<EOF > configure.local
CC=x86_64-linux-musl-gcc
CFLAGS="-static -I$BASE_DIR/zlib-dist/include"
LDFLAGS="-static -L$BASE_DIR/zlib-dist/lib"
PREFIX=/usr
MANDIR=/usr/share/man
EOF
    ./configure
    make "-j$(nproc)"
    # Create Busybox-compatible wrappers in source for reproducibility
    WRAPPER_DIR="$SRC_ROOT/mandoc-wrappers"
    mkdir -p "$WRAPPER_DIR"

    cat <<EOF > "$WRAPPER_DIR/nroff"
#!/bin/sh
# Robust nroff wrapper for mandoc
REAL_MANDOC="\$(dirname "\$0")/mandoc"
[ -f "\$REAL_MANDOC" ] || REAL_MANDOC="mandoc"
cmd_args=""
for arg in "\$@"; do
    case "\$arg" in
        -r*) ;; # Skip registers
        -T*) ;; # Skip T settings
        *) cmd_args="\$cmd_args \$arg" ;;
    esac
done
# shellcheck disable=SC2086
exec "\$REAL_MANDOC" -Tascii \$cmd_args
EOF

    cat <<EOF > "$WRAPPER_DIR/col"
#!/bin/sh
# Simple col -b replacement to strip overstrikes
while [ \$# -gt 0 ]; do
    case "\$1" in
        -*) shift ;;
        *) break ;;
    esac
done
# Handle literal backspaces and mangled question marks
# shellcheck disable=SC2086
exec sed 's/\(.\)[\x08?]\1/\1/g; s/_[\x08?]\(.\)/\1/g; s/.\x08//g' "\$@"
EOF

    cat <<EOF > "$WRAPPER_DIR/less"
#!/bin/sh
# Wrapper to swallow -T flag and strip overstrikes
args=""
while [ \$# -gt 0 ]; do
    case "\$1" in
        -T) shift; shift ;;
        *) args="\$args \$1"; shift ;;
    esac
done
# Pipe through col to strip overstrikes before viewing
# shellcheck disable=SC2086
"\$(dirname "\$0")/col" | busybox less -RS \$args
EOF

    chmod +x "$WRAPPER_DIR"/*

    mkdir -p "$BIN_DIR/mandoc-bin"
    cp mandoc demandoc soelim "$BIN_DIR/mandoc-bin/"
    cp "$WRAPPER_DIR"/* "$BIN_DIR/mandoc-bin/"

    # Create symlinks for unified tools
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
chmod +x "$BIN_DIR/pfetch"

echo "--- Building ncurses Statically ---"
if [ ! -d "$SRC_ROOT/ncurses" ]; then
    curl -L https://ftp.gnu.org/pub/gnu/ncurses/ncurses-6.4.tar.gz -o "$CACHE_DIR/ncurses.tar.gz"
    mkdir -p "$SRC_ROOT/ncurses"
    tar -xzf "$CACHE_DIR/ncurses.tar.gz" -C "$SRC_ROOT/ncurses" --strip-components=1
fi
(
    cd "$SRC_ROOT/ncurses" || exit
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

echo "--- Building htop Statically ---"
if [ ! -d "$SRC_ROOT/htop" ]; then
    curl -L https://github.com/htop-dev/htop/archive/refs/tags/3.3.0.tar.gz -o "$CACHE_DIR/htop.tar.gz"
    mkdir -p "$SRC_ROOT/htop"
    tar -xzf "$CACHE_DIR/htop.tar.gz" -C "$SRC_ROOT/htop" --strip-components=1
fi
(
    cd "$SRC_ROOT/htop" || exit
    ./autogen.sh
    # LIBS forces -lncurses -ltinfo so configure's curses probe succeeds with our widec symlinks
    CC="x86_64-linux-musl-gcc" \
    CFLAGS="-static -I$BASE_DIR/ncurses-dist/include -I$BASE_DIR/ncurses-dist/include/ncursesw" \
    LDFLAGS="-static -L$BASE_DIR/ncurses-dist/lib" \
    LIBS="-lncurses -ltinfo" \
    ./configure --host=x86_64-pc-linux-gnu \
                --enable-static \
                --disable-unicode \
                --disable-shared
    make "-j$(nproc)"
    rm -f "$BIN_DIR/htop"
    cp htop "$BIN_DIR/htop"
)

echo "--- Building btop Statically ---"
if [ ! -d "$SRC_ROOT/btop" ]; then
    curl -L https://github.com/aristocratos/btop/archive/refs/tags/v1.3.2.tar.gz -o "$CACHE_DIR/btop.tar.gz"
    mkdir -p "$SRC_ROOT/btop"
    tar -xzf "$CACHE_DIR/btop.tar.gz" -C "$SRC_ROOT/btop" --strip-components=1
fi
(
    cd "$SRC_ROOT/btop" || exit
    # btop has a built-in STATIC=true flag that handles all static linking flags correctly
    make STATIC=true \
         CXX="x86_64-linux-musl-g++" \
         AR="x86_64-linux-musl-ar" \
         RANLIB="x86_64-linux-musl-ranlib" \
         "-j$(nproc)"
    rm -f "$BIN_DIR/btop"
    cp bin/btop "$BIN_DIR/btop"
)

echo "--- Finalizing and Cleanup ---"
rm -rf "$BASE_DIR/zlib-dist" "$BASE_DIR/ncurses-dist"
# Strip debug info from single-binary tools to reduce size
x86_64-linux-musl-strip "$BIN_DIR/htop" "$BIN_DIR/btop" 2>/dev/null || true
# Safely chmod only actual files in BIN_DIR to avoid dangling symlink errors
find "$BIN_DIR" -maxdepth 1 -type f -exec chmod +x {} +
echo "Build complete."
ls -l "$BIN_DIR"
