#!/bin/sh
# Clone, build and install the GNUstep core libraries into /System/Library,
# using a stock upstream libdispatch, built without Mach, instead of the one
# in the NextBSD base system. This is the backup method from the wiki guide.
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
CPUS=$(sysctl -n hw.ncpu)

# Keep configure off C23, which GNUstep doesn't compile under.
export CC=clang CXX=clang++ OBJC=clang
export ac_cv_prog_cc_c23=no

# Stock libdispatch installs libdispatch.so and libBlocksRuntime.so under
# their usual names, so no link-only symlinks are needed.
LINKDIR=/System/Library/Libraries
DISPATCH_INCLUDE=/System/Library/Headers
BLOCKS_INCLUDE=/System/Library/Headers
BLOCKS_LIB=/System/Library/Libraries/libBlocksRuntime.so

# clang doesn't search /usr/X11 by itself.
export CPATH=/usr/X11/include
export LIBRARY_PATH=/usr/X11/lib:$LINKDIR
export GNUSTEP_INSTALLATION_DOMAIN=SYSTEM

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

# Known-good commits. Each clone is checked out at its commit, so the build
# doesn't change as upstream does.
pin() {
    case "$1" in
        tools-make)                 echo 4e31a0310df5 ;;
        libobjc2)                   echo c9f4002ade04 ;;
        libs-base)                  echo 5bda52220a6d ;;
        libs-corebase)              echo e89ff1f5b878 ;;
        libs-gui)                   echo 8f804fd520c6 ;;
        libs-back)                  echo bbcc3de7cab6 ;;
        libs-av)                    echo 26566e25043f ;;
        swift-corelibs-libdispatch) echo 95f592ab637c ;;
    esac
}

# Clone a repository into $SOURCES, or fetch an existing clone, then check out
# its pinned commit.
clone_pinned() {
    url=$1
    dir="$SOURCES/$(basename "$url" .git)"
    if [ -d "$dir/.git" ]; then
        git -C "$dir" fetch origin
    else
        git clone "$url" "$dir"
    fi
    git -C "$dir" checkout -q "$(pin "$(basename "$dir")")"
}

echo "==> Cloning sources"
mkdir -p "$SOURCES"
# The Mach sed below edits libdispatch's checkout, so put it back first or
# git checkout refuses to move to another commit.
if [ -d "$SOURCES/swift-corelibs-libdispatch/.git" ]; then
    git -C "$SOURCES/swift-corelibs-libdispatch" checkout -- .
fi
clone_pinned https://github.com/apple/swift-corelibs-libdispatch.git
for lib in tools-make libobjc2 libs-base libs-corebase libs-gui libs-back libs-av; do
    clone_pinned "https://github.com/gnustep/$lib.git"
done

echo "==> Building libdispatch"
cd "$SOURCES/swift-corelibs-libdispatch"
# <mach/mach.h> exists system-wide on NextBSD, so turn off the source's Mach
# paths.
grep -rl "__has_include(<mach/mach.h>)" . | grep -vE "/\.git/|/Build/" |
    xargs -r sed -i.nbsdbak "s#__has_include(<mach/mach.h>)#0#g"
rm -rf Build
mkdir Build
cd Build
cmake .. \
    -DCMAKE_SYSTEM_NAME=FreeBSD \
    -DCMAKE_INSTALL_PREFIX=/System/Library \
    -DCMAKE_INSTALL_LIBDIR=Libraries \
    -DINSTALL_DISPATCH_HEADERS_DIR=/System/Library/Headers/dispatch \
    -DINSTALL_BLOCK_HEADERS_DIR=/System/Library/Headers \
    -DINSTALL_OS_HEADERS_DIR=/System/Library/Headers/os \
    -DINSTALL_PRIVATE_HEADERS=ON \
    -DCMAKE_INSTALL_MANDIR=Documentation/man \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DHAVE_MACH=OFF
gmake -j"$CPUS"
gmake install

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
# no Bonjour support and NSNetServiceBrowser crashes. It comes after
# /System/Library/Libraries, so -ldispatch finds the stock libdispatch.
./configure \
    $BUILD_FLAG \
    --with-dispatch-include="$DISPATCH_INCLUDE" \
    --with-dispatch-library="$LINKDIR" \
    --with-zeroconf-api=mdns \
    LDFLAGS="-L/System/Library/Libraries -L/usr/lib/system"
make_install

ICU_CFLAGS=$(pkg-config --cflags icu-i18n)

echo "==> Building libs-corebase"
cd "$SOURCES/libs-corebase"
./configure \
    $BUILD_FLAG \
    CPPFLAGS="-I/System/Library/Headers" \
    LDFLAGS="-L/System/Library/Libraries"
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
