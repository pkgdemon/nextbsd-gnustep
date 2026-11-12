#!/bin/sh
# Go back to booting to the text console: disable loginwindow and
# WindowServer. Run as root. Any graphical session ends now. getty comes
# back on ttyv0 within a minute.

if [ "$(id -u)" -ne 0 ]; then
    echo "$0: must be run as root" >&2
    exit 1
fi

DAEMONS=/System/Library/LaunchDaemons
LW_PLIST=$DAEMONS/org.nextbsd.loginwindow.plist
WS_PLIST=$DAEMONS/org.nextbsd.WindowServer.plist

if [ -f "$LW_PLIST" ]; then
    echo "==> Disabling loginwindow"
    launchctl unload -w "$LW_PLIST" 2>/dev/null
    rm -f "$LW_PLIST"
fi

if [ -f "$WS_PLIST" ]; then
    echo "==> Disabling WindowServer"
    # SIGTERM, from unload, gives the console back; never kill -9 it.
    launchctl unload -w "$WS_PLIST" 2>/dev/null
fi

echo "==> Done. The text console comes back within a minute."
