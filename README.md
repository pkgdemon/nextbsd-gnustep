# nextbsd-gnustep

The purpose of this project is testing WindowServer.app development. X is an optional component for compatibility, installed on demand when an app needs it. The [WindowServer.app development plan](https://pkgdemon.github.io/WindowServer-Plan.html?v=20260514) is driving this work.

libdispatch and the blocks runtime come from the NextBSD base system, which may become a factor in this work. [Building GNUstep core libraries on NextBSD](https://github.com/pkgdemon/pkgdemon.github.io/wiki/Building-GNUstep--Core-Libraries-on-NextBSD) covers the known problem with main queue wakeups and keeps a stock libdispatch build as a backup. There is a script for each.

Scripts that build the GNUstep core libraries on NextBSD, using only NextBSD packages. For the desktop apps, see [nextbsd-gnustep-apps](https://github.com/pkgdemon/nextbsd-gnustep-apps).

The libraries are stock upstream sources, from the latest commit on each default branch. Nothing is pinned, so what you build changes as upstream does.

## Packages

Install these first, as root. `git` comes from `NextBSD-toolchain`, so you need it before you can clone this repository.

Needed for WindowServer.app development:

```sh
pkg install -y NextBSD-toolchain NextBSD-mesa NextBSD-gnustep-support
```

Optional X libraries:

```sh
pkg install -y NextBSD-xlibre NextBSD-xlibs NextBSD-mesa-x11
```

Optional CUPS for printing support:

```sh
pkg install -y NextBSD-printing-support
```

| Package | Provides |
|---|---|
| `NextBSD-toolchain` | clang and lld 19.1.7, gmake, pkgconf, git, CMake, autoconf, automake, libtool |
| `NextBSD-xlibs` | X client libraries in `/usr/X11` |
| `NextBSD-mesa`, `NextBSD-mesa-x11` | EGL, OpenGL, GLX |
| `NextBSD-gnustep-support` | jpeg-turbo, libpng, libtiff, giflib, GnuTLS, cairo, libsndfile, libao, SQLite, flite, FFmpeg |
| `NextBSD-printing-support` | Apple's CUPS, used by libs-gui for printing |

Then clone this repository:

```sh
git clone https://github.com/pkgdemon/nextbsd-gnustep.git /private/tmp/nextbsd-gnustep
cd /private/tmp/nextbsd-gnustep
```

## Build

There are two scripts. They differ only in where libdispatch and the blocks runtime come from. Run one of them as root.

NextBSD's libdispatch, from the base system:

```sh
./build-core-libs-nextbsd-dispatch.sh
```

Stock libdispatch, the backup method:

```sh
./build-core-libs-stock-dispatch.sh
```

| Script | libdispatch and blocks runtime |
|---|---|
| `build-core-libs-nextbsd-dispatch.sh` | `libsystem_dispatch` and `libsystem_blocks` from `/usr/lib/system`, with Mach enabled. This is the main method. |
| `build-core-libs-stock-dispatch.sh` | Apple's upstream [swift-corelibs-libdispatch](https://github.com/apple/swift-corelibs-libdispatch), built without Mach and installed into `/System/Library`. Useful for comparing behaviour. |

Both have the same known problem with main queue wakeups. With the stock libdispatch, fixing it would mean patching libs-base.

Don't mix the two on one machine. The NextBSD script stops if a stock libdispatch is already in `/System/Library`, because it would be linked instead of NextBSD's.

Each script clones and builds the core libraries into `/System/Library`. It can be re-run. Existing clones are updated with `git pull --ff-only`, and the script stops at the first failure.

### Core libraries

Built in this order, because each needs the ones before it:

| Library | What it is |
|---|---|
| tools-make | gnustep-make, with the `gershwin` filesystem layout |
| libobjc2 | Objective-C runtime |
| libs-base | Foundation |
| libs-corebase | Core Foundation |
| libs-gui | AppKit |
| libs-back | X11 drawing backend, using cairo |
| libs-av | Audio and video, using FFmpeg |

The stock script builds libdispatch first, before tools-make.

Sources are cloned into `/Developer/Sources`.

## Uninstall

Run this as root:

```sh
./uninstall-core-libs.sh
```

It's a shell version of the `uninstall` target in [gershwin-developer's Makefile](https://github.com/gershwin-desktop/gershwin-developer/blob/main/Makefile). On NextBSD it removes `/System/Applications` and everything in `/System/Library` except `Caches`, `Extensions`, `Filesystems`, `LaunchAgents` and `LaunchDaemons`, which belong to the base system. The Makefile keeps only `Caches`, `Extensions` and `LaunchDaemons`; the other two were added because NextBSD installs into them. It also removes the sources in `/Developer/Sources`.

## Guide

These scripts automate a wiki guide, which explains why each flag is there:

- [Building GNUstep core libraries on NextBSD](https://github.com/pkgdemon/pkgdemon.github.io/wiki/Building-GNUstep--Core-Libraries-on-NextBSD), whose [Backup: stock libdispatch](https://github.com/pkgdemon/pkgdemon.github.io/wiki/Building-GNUstep--Core-Libraries-on-NextBSD#backup-stock-libdispatch) section is the stock script
