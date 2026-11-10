#!/bin/sh
# Clone, build and install the GNUstep core libraries into /System/Library.
# Run as root, after installing the packages listed in README.md.
#
# Commands run one per line rather than joined with &&, because set -e does
# not stop the script when a command other than the last in a && list fails.

set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "$0: must be run as root" >&2
    exit 1
fi

# GNUstep refuses a group-writable GNUstep.conf.
umask 022

SOURCES=/Developer/Sources
LINKDIR=/Developer/Link
CPUS=$(sysctl -n hw.ncpu)

# Keep configure off C23, which GNUstep doesn't compile under.
export CC=clang CXX=clang++ OBJC=clang
export ac_cv_prog_cc_c23=no

# clang doesn't search /usr/X11 by itself.
export CPATH=/usr/X11/include
export LIBRARY_PATH=/usr/X11/lib:$LINKDIR
export GNUSTEP_INSTALLATION_DOMAIN=SYSTEM

# NextBSD's libraries are deliberately not named libdispatch.so or
# libBlocksRuntime.so, but GNUstep's builds link -ldispatch. These symlinks
# satisfy the linker only. Keep LINKDIR out of every runtime search path.
mkdir -p "$LINKDIR"
ln -sf /usr/lib/system/libsystem_dispatch.so "$LINKDIR/libdispatch.so"
ln -sf /usr/lib/system/libsystem_blocks.so "$LINKDIR/libBlocksRuntime.so"
BLOCKS_INCLUDE=/usr/include
BLOCKS_LIB=/usr/lib/system/libsystem_blocks.so

# config.guess doesn't recognise NextBSD.
ARCH=$(uname -m)
[ "$ARCH" = amd64 ] && ARCH=x86_64
BUILD_FLAG="--build=${ARCH}-nextbsd-freebsd"

make_install() {
    gmake -j"$CPUS" "$@"
    gmake install
    gmake clean
}

# GNUstep.sh isn't written to run under set -e.
source_gnustep() {
    set +e
    . /System/Library/Makefiles/GNUstep.sh
    set -e
    export GNUSTEP_INSTALLATION_DOMAIN=SYSTEM
}

echo "==> Cloning sources"
mkdir -p "$SOURCES"
for lib in tools-make libobjc2 libs-base libs-corebase libs-gui libs-back libs-av; do
    if [ -d "$SOURCES/$lib/.git" ]; then
        git -C "$SOURCES/$lib" pull --ff-only
    else
        git clone "https://github.com/gnustep/$lib.git" "$SOURCES/$lib"
    fi
done

echo "==> Building tools-make"
cd "$SOURCES/tools-make"
# libobjc_LIBS and --with-objc-lib-flag keep -lobjc out of configure's link
# tests, since libobjc2 isn't built yet.
./configure \
    $BUILD_FLAG \
    --with-config-file=/System/Library/Preferences/GNUstep.conf \
    --with-layout=gershwin \
    --with-library-combo=ng-gnu-gnu \
    --with-objc-lib-flag=" " \
    LDFLAGS="-L/System/Library/Libraries" \
    CPPFLAGS="-I/System/Library/Headers" \
    libobjc_LIBS=" "
gmake
gmake install

source_gnustep

echo "==> Building libobjc2"
cd "$SOURCES/libobjc2"
rm -rf Build
mkdir Build
cd Build
cmake .. \
    -DGNUSTEP_INSTALL_TYPE=SYSTEM \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DEMBEDDED_BLOCKS_RUNTIME=OFF \
    -DBlocksRuntime_INCLUDE_DIR="$BLOCKS_INCLUDE" \
    -DBlocksRuntime_LIBRARIES="$BLOCKS_LIB"
gmake -j"$CPUS"
gmake install

echo "==> Building libs-base"
cd "$SOURCES/libs-base"
# -L/usr/lib/system lets configure find libdns_sd. Without it, libs-base has
# no Bonjour support and NSNetServiceBrowser crashes.
./configure \
    $BUILD_FLAG \
    --with-dispatch-include=/usr/include \
    --with-dispatch-library="$LINKDIR" \
    --with-zeroconf-api=mdns \
    LDFLAGS="-L/System/Library/Libraries -L$LINKDIR -L/usr/lib/system"
make_install

ICU_CFLAGS=$(pkg-config --cflags icu-i18n)

echo "==> Building libs-corebase"
cd "$SOURCES/libs-corebase"
./configure \
    $BUILD_FLAG \
    CPPFLAGS="-I/System/Library/Headers" \
    LDFLAGS="-L/System/Library/Libraries -L$LINKDIR"
# configure doesn't pass the ICU header path on to the compile.
make_install CPPFLAGS="-I/System/Library/Headers $ICU_CFLAGS"

echo "==> Building libs-gui"
cd "$SOURCES/libs-gui"
./configure $BUILD_FLAG CPPFLAGS="$ICU_CFLAGS"
make_install

echo "==> Building libs-back"
cd "$SOURCES/libs-back"
export fonts=no
./configure $BUILD_FLAG
make_install

echo "==> Building libs-av"
cd "$SOURCES/libs-av"
make_install
