#!/bin/sh
# Clone, build and install WindowServer and the GNUstep nextbsd backend.
# Run as root, after build-core-libs-nextbsd-dispatch.sh.
#
#   WindowServer   nextbsd/apps-windowserver: the display server, its client
#                  library and test tools.
#   nextbsd        nextbsd/libs-back (a fork of libs-back): the GNUstep backend
#                  apps load to talk to WindowServer, installed as
#                  libgnustep-nextbsd beside the stock X11 libgnustep-back.
#   loginwindow    nextbsd/apps-loginwindow: the graphical login. Installing
#                  it doesn't enable it; enable-loginwindow.sh does.
#
# Commands run one per line rather than joined with &&, because set -e does
# not stop the script when a command other than the last in a && list fails.

set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "$0: must be run as root" >&2
    exit 1
fi

# The nextbsd backend talks to WindowServer over Mach, so it needs NextBSD's
# Mach-enabled libdispatch, not the stock one.
if [ -e /System/Library/Libraries/libdispatch.so ] ||
    [ -e /System/Library/Headers/dispatch ]; then
    echo "$0: a stock libdispatch is installed in /System/Library." >&2
    echo "WindowServer needs the core libraries from build-core-libs-nextbsd-dispatch.sh." >&2
    exit 1
fi

if [ ! -r /System/Library/Makefiles/GNUstep.sh ]; then
    echo "$0: the GNUstep core libraries aren't installed." >&2
    echo "Run build-core-libs-nextbsd-dispatch.sh first." >&2
    exit 1
fi

umask 022

SOURCES=/Developer/Sources
LINKDIR=/Developer/Link
CPUS=$(sysctl -n hw.ncpu)

# The same build environment as build-core-libs-nextbsd-dispatch.sh.
export CC=clang CXX=clang++ OBJC=clang
export ac_cv_prog_cc_c23=no
export CPATH=/usr/X11/include
export LIBRARY_PATH=/usr/X11/lib:$LINKDIR
export GNUSTEP_INSTALLATION_DOMAIN=SYSTEM

ARCH=$(uname -m)
[ "$ARCH" = amd64 ] && ARCH=x86_64
BUILD_FLAG="--build=${ARCH}-nextbsd-freebsd"

# GNUstep.sh isn't written to run under set -e.
source_gnustep() {
    set +e
    . /System/Library/Makefiles/GNUstep.sh
    set -e
    export GNUSTEP_INSTALLATION_DOMAIN=SYSTEM
}

# Clone a repository into $SOURCES/<dir>, or bring an existing clone up to
# date with its default branch.
clone_or_pull() {
    url=$1
    dir="$SOURCES/$2"
    if [ -d "$dir/.git" ]; then
        git -C "$dir" fetch origin
        branch=$(git -C "$dir" symbolic-ref --short refs/remotes/origin/HEAD)
        git -C "$dir" checkout -q "${branch#origin/}"
        git -C "$dir" pull --ff-only
    else
        git clone "$url" "$dir"
    fi
}

echo "==> Cloning sources"
mkdir -p "$SOURCES"
clone_or_pull https://github.com/nextbsd/apps-windowserver.git apps-windowserver
# A different directory from the stock libs-back clone the core-libs script
# uses, so the two never mix.
clone_or_pull https://github.com/nextbsd/libs-back.git libs-back-nextbsd
clone_or_pull https://github.com/nextbsd/apps-loginwindow.git apps-loginwindow

echo "==> Building WindowServer"
cd "$SOURCES/apps-windowserver"
gmake -j"$CPUS"
# Installs the server to /System/Library/CoreServices, the client library and
# headers to /usr, and the LaunchDaemon, which ships disabled.
gmake install
gmake clean

source_gnustep

echo "==> Building the nextbsd backend"
cd "$SOURCES/libs-back-nextbsd"
# Like the stock libs-back build, don't install the font set.
export fonts=no
./configure \
    $BUILD_FLAG \
    --enable-server=nextbsd \
    --enable-graphics=cairo \
    --with-name=nextbsd \
    --without-x
# Only Source/: a top-level install would also put this build's gpbs,
# back.make and fonts over the stock X11 ones.
gmake -C Source -j"$CPUS"
gmake -C Source install
gmake -C Source clean

echo "==> Building loginwindow"
cd "$SOURCES/apps-loginwindow"
gmake -j"$CPUS"
# The app goes to /System/Library/CoreServices with its LaunchDaemon plist
# inside it, and the PAM service to /etc/pam.d/loginwindow if there's none.
gmake install
gmake clean

echo "==> Done"
echo "WindowServer:    /System/Library/CoreServices/WindowServer"
echo "nextbsd backend: /System/Library/Bundles/libgnustep-nextbsd-*.bundle"
echo "loginwindow:     /System/Library/CoreServices/loginwindow.app"
echo "Tools:           /usr/libexec/WindowServer (ws-session, wstest, wsctl)"
echo "To boot to the login panel: ./enable-loginwindow.sh"
echo "See README.md, \"Trying WindowServer\", for how to start it."
