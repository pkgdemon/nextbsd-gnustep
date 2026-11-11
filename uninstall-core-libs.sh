#!/bin/sh
# Remove the GNUstep System Domain installed by the build scripts, and the
# sources they cloned into /Developer/Sources.
# Run as root. A shell version of the uninstall target in gershwin-developer's
# Makefile.
#
# On NextBSD, /System/Library also holds base system files, so only the
# GNUstep parts are removed. Caches, Extensions, Filesystems, LaunchAgents
# and LaunchDaemons are kept.

if [ "$(id -u)" -ne 0 ]; then
    echo "$0: must be run as root" >&2
    exit 1
fi

if [ -d /usr/lib/system ]; then
    echo "NextBSD system detected. Performing selective uninstall..."
    if [ -d /System/Applications ]; then
        rm -rf /System/Applications
        echo "Removed /System/Applications"
    fi
    for dir in /System/Library/*/; do
        name=$(basename "$dir")
        case "$name" in
            Caches|Extensions|Filesystems|LaunchAgents|LaunchDaemons)
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

# The sources cloned by the build scripts.
if [ -d /Developer/Sources ]; then
    rm -rf /Developer/Sources
    echo "Removed /Developer/Sources"
fi
