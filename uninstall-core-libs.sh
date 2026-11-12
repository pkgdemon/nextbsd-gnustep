#!/bin/sh
# Remove the GNUstep System Domain installed by the build scripts, the
# WindowServer files from build-windowserver.sh, the sources they cloned into
# /Developer/Sources, and the link-only symlinks in /Developer/Link.
# Run as root. A shell version of the uninstall target in gershwin-developer's
# Makefile.
#
# On NextBSD, /System/Library also holds base system files, so only the
# GNUstep parts are removed. Caches, CoreServices, Extensions, Filesystems,
# LaunchAgents and LaunchDaemons are kept: NextBSD's base packages install
# into all but Caches.

if [ "$(id -u)" -ne 0 ]; then
    echo "$0: must be run as root" >&2
    exit 1
fi

if [ -d /usr/lib/system ]; then
    echo "NextBSD system detected. Performing selective uninstall..."
    # WindowServer's own files sit in folders the base system shares, or
    # outside /System, so they are removed one by one.
    for f in /System/Library/CoreServices/WindowServer \
        /System/Library/LaunchDaemons/org.nextbsd.WindowServer.plist \
        /usr/include/WindowServer /usr/libexec/WindowServer \
        /usr/libdata/pkgconfig/WindowServerClient.pc \
        /usr/lib/libWindowServerClient.so /usr/lib/libWindowServerClient.so.1 \
        /usr/lib/libWindowServerClient.a; do
        if [ -e "$f" ] || [ -L "$f" ]; then
            rm -rf "$f"
            echo "Removed $f"
        fi
    done
    if [ -d /System/Applications ]; then
        rm -rf /System/Applications
        echo "Removed /System/Applications"
    fi
    for dir in /System/Library/*/; do
        name=$(basename "$dir")
        case "$name" in
            Caches|CoreServices|Extensions|Filesystems|LaunchAgents|LaunchDaemons)
                echo "Keeping /System/Library/$name";;
            *)
                rm -rf "$dir"
                echo "Removed /System/Library/$name";;
        esac
    done
    echo "Selective uninstall complete."
elif [ -d /System/Library ]; then
    rm -rf /System >/dev/null 2>&1 || true
    echo "Removed GNUstep System Domain /System"
    echo "Uninstallation complete: /System"
else
    echo "GNUstep appears to be already uninstalled. Nothing was removed."
fi

# The sources cloned by the build scripts, and the link-only symlinks made by
# build-core-libs-nextbsd-dispatch.sh.
for dir in /Developer/Sources /Developer/Link; do
    if [ -d "$dir" ]; then
        rm -rf "$dir"
        echo "Removed $dir"
    fi
done
