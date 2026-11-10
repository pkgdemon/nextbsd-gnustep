#!/bin/sh
# Check that the GNUstep core libraries are installed and linked correctly.
# Changes nothing on the system. Exits non-zero if any check fails.

LIBS=/System/Library/Libraries
BASE=$LIBS/libgnustep-base.so
FAILED=0

pass() {
    echo "ok    $1"
}

fail() {
    echo "FAIL  $1"
    FAILED=1
}

. /System/Library/Makefiles/GNUstep.sh

for lib in libobjc libgnustep-base libgnustep-corebase libgnustep-gui; do
    if [ -e "$LIBS/$lib.so" ]; then
        pass "$lib.so is installed"
    else
        fail "$lib.so is missing from $LIBS"
    fi
done

LDD=$(ldd "$BASE")

check_resolves() {
    if echo "$LDD" | grep -Eq "$1[^ ]* => $2/"; then
        pass "$1 resolves to $2"
    else
        fail "$1 does not resolve to $2"
    fi
}

check_resolves libobjc "$LIBS"
check_resolves libsystem_dispatch /usr/lib/system
check_resolves libsystem_blocks /usr/lib/system
check_resolves libdns_sd /usr/lib/system

NEEDED=$(readelf -d "$BASE" | grep NEEDED | grep -i dispatch)
if echo "$NEEDED" | grep -q 'libsystem_dispatch\.so'; then
    pass "libgnustep-base needs libsystem_dispatch.so"
else
    fail "libgnustep-base would load the wrong dispatch library: $NEEDED"
fi

SYSTEM_LIBS=$(gnustep-config --variable=GNUSTEP_SYSTEM_LIBRARIES)
if [ "$SYSTEM_LIBS" = "$LIBS" ]; then
    pass "gnustep-config reports $LIBS"
else
    fail "gnustep-config reports '$SYSTEM_LIBS', expected $LIBS"
fi

if fc-match monospace | grep -q 'DejaVu Sans Mono'; then
    pass "fontconfig finds DejaVu Sans Mono"
else
    fail "fc-match monospace printed: $(fc-match monospace)"
fi

exit $FAILED
