#!/bin/sh
# Build and install the NextBSD desktop apps and theme under your home folder.
# Run as a normal user, after build-core-libs.sh.
#
# Usage: install-apps.sh [--with-windowmanager]

set -e

WINDOWMANAGER=no
case "${1:-}" in
    "") ;;
    --with-windowmanager) WINDOWMANAGER=yes ;;
    *)
        echo "usage: $0 [--with-windowmanager]" >&2
        exit 1
        ;;
esac

if [ "$(id -u)" -eq 0 ]; then
    echo "$0: run this as a normal user, not root" >&2
    exit 1
fi

# GNUstep.sh isn't written to run under set -e.
set +e
. /System/Library/Makefiles/GNUstep.sh
set -e
export LIBRARY_PATH=/usr/X11/lib:/Developer/Link
export CPATH=/usr/X11/include
export GNUSTEP_INSTALLATION_DOMAIN=USER

clone_or_pull() {
    dir=$HOME/$(basename "$1" .git)
    if [ -d "$dir/.git" ]; then
        git -C "$dir" pull --ff-only
    else
        git clone "$1" "$dir"
    fi
}

for repo in nextbsd-theme apps-terminal Finder apps-dock apps-innerspace; do
    clone_or_pull "https://github.com/pkgdemon/$repo.git"
done

for repo in nextbsd-theme apps-terminal Finder apps-dock apps-innerspace; do
    echo "==> Building $repo"
    cd "$HOME/$repo"
    gmake install
done

if [ "$WINDOWMANAGER" = yes ]; then
    clone_or_pull https://github.com/pkgdemon/gnustep-windowmanager.git
    echo "==> Building gnustep-windowmanager"
    cd "$HOME/gnustep-windowmanager"
    gmake
    gmake install
fi

defaults write NSGlobalDomain GSTheme NextBSD
defaults write NSGlobalDomain GSBackHandlesWindowDecorations NO

echo "==> Done. Set up ~/.zprofile and ~/.xinitrc as described in the README, then run startx."
