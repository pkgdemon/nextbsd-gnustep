#!/bin/sh
# Boot to the graphical login: enable WindowServer and loginwindow.
# Run as root, after build-windowserver.sh. The login panel replaces the
# text console right away, and at every boot after this.
#
# WindowServer's LaunchDaemon is enabled with launchctl load -w, which
# records the choice in launchd's overrides. loginwindow's plist is copied
# from the app into /System/Library/LaunchDaemons and loaded: an installed
# org.nextbsd.loginwindow.plist is how NextBSD knows a graphical login owns
# the console (getty stays off ttyv0; console automatic login and the
# banner stand down).

set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "$0: must be run as root" >&2
    exit 1
fi

DAEMONS=/System/Library/LaunchDaemons
WS_PLIST=$DAEMONS/org.nextbsd.WindowServer.plist
LW_SRC=/System/Library/CoreServices/loginwindow.app/Resources/org.nextbsd.loginwindow.plist
LW_PLIST=$DAEMONS/org.nextbsd.loginwindow.plist
GETTY_PLIST=$DAEMONS/org.nextbsd.getty.plist

for f in /System/Library/CoreServices/WindowServer "$WS_PLIST" "$LW_SRC"; do
    if [ ! -e "$f" ]; then
        echo "$0: $f is missing. Run build-windowserver.sh first." >&2
        exit 1
    fi
done

if pgrep -q -x Xorg; then
    echo "$0: X is running and owns the console. Quit X first." >&2
    exit 1
fi

# getty only steps aside for org.nextbsd.loginwindow once
# nextbsd-userland#606 is in this NextBSD build.
if ! grep -q org.nextbsd.loginwindow "$GETTY_PLIST" 2>/dev/null; then
    echo "warning: this NextBSD's getty doesn't know org.nextbsd.loginwindow yet" >&2
    echo "(nextbsd-userland#606), so a text login will still start on ttyv0." >&2
fi

# A WindowServer started by hand with ws-session would hold the console.
if [ -x /usr/libexec/WindowServer/ws-session ]; then
    /usr/libexec/WindowServer/ws-session stop >/dev/null 2>&1 || true
fi

echo "==> Enabling WindowServer"
launchctl load -w "$WS_PLIST"

echo "==> Enabling loginwindow"
install -m 644 "$LW_SRC" "$LW_PLIST"
launchctl load -w "$LW_PLIST"

echo "==> Done. The login panel should be on the screen now."
echo "./disable-loginwindow.sh goes back to the text console."
