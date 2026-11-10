# nextbsd-gnustep

The purpose of this project is testing WindowServer.app development. X is an optional component for compatibility, installed on demand when an app needs it. The [WindowServer.app development plan](https://pkgdemon.github.io/WindowServer-Plan.html?v=20260514) is driving this work.

libdispatch and the blocks runtime come from the NextBSD base system, which may become a factor in this work. [Building GNUstep core libraries on NextBSD](https://github.com/pkgdemon/pkgdemon.github.io/wiki/Building-GNUstep--Core-Libraries-on-NextBSD) covers the known problem with main queue wakeups and keeps a stock libdispatch build as a backup.

A script that builds the GNUstep core libraries on NextBSD, using only NextBSD packages. For the desktop apps, see [nextbsd-gnustep-apps](https://github.com/pkgdemon/nextbsd-gnustep-apps).

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

Run this as root:

```sh
./build-core-libs.sh
```

It clones and builds the core libraries into `/System/Library`. It can be re-run. Existing clones are updated with `git pull --ff-only`, and the script stops at the first failure.

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

Sources are cloned into `/Developer/Sources`.

## Guide

This script automates a wiki guide, which explains why each flag is there:

- [Building GNUstep core libraries on NextBSD](https://github.com/pkgdemon/pkgdemon.github.io/wiki/Building-GNUstep--Core-Libraries-on-NextBSD)
