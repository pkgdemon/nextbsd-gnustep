#!/bin/sh
# Install the NextBSD packages needed to build GNUstep. Run as root.

set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "$0: must be run as root" >&2
    exit 1
fi

# -r NextBSD keeps pkg to the NextBSD repository, even if another has been added.
pkg install -y -r NextBSD \
    NextBSD-toolchain \
    NextBSD-mesa \
    NextBSD-gnustep-support \
    NextBSD-xlibre \
    NextBSD-xlibs \
    NextBSD-mesa-x11 \
    NextBSD-printing-support
