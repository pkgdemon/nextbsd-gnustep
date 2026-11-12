# nextbsd-gnustep

The purpose of this project is testing WindowServer.app development. X is an optional component for compatibility, installed on demand when an app needs it. The [WindowServer.app development plan](https://pkgdemon.github.io/WindowServer-Plan.html?v=20260514) is driving this work.

libdispatch and the blocks runtime come from the NextBSD base system, which may become a factor in this work. [Building GNUstep core libraries on NextBSD](https://github.com/pkgdemon/pkgdemon.github.io/wiki/Building-GNUstep--Core-Libraries-on-NextBSD) covers the known problem with main queue wakeups and keeps a stock libdispatch build as a backup. There is a script for each.

Scripts that build the GNUstep core libraries on NextBSD, using only NextBSD packages. For the desktop apps, see [nextbsd-gnustep-apps](https://github.com/pkgdemon/nextbsd-gnustep-apps).

The libraries are stock upstream sources, from the latest commit on each default branch. Nothing is pinned, so what you build changes as upstream does.

## Install the NextBSD desktop

On a fresh NextBSD install, these steps take you from the text console to the login window. Each is explained further down.

1. As root, install the [packages](#packages), the optional X libraries included (XLibre.app and its `xterm` need them), and clone this repository. Then build the core libraries:

   ```sh
   ./build-core-libs-nextbsd-dispatch.sh
   ```

2. As root, build [WindowServer](#windowserver), the `nextbsd` backend and loginwindow:

   ```sh
   ./build-windowserver.sh
   ```

3. As your normal user, not root, build and install the desktop apps with `install-apps.sh` from [nextbsd-gnustep-apps](https://github.com/pkgdemon/nextbsd-gnustep-apps#install): the theme, Terminal, Workspace, the Dock, InnerSpace and XLibre.app (it fetches XLibre's X server, `Xnextbsd`, from [apps-xlibre's CI release](https://github.com/nextbsd/apps-xlibre/releases/tag/xnextbsd-latest)):

   ```sh
   git clone https://github.com/pkgdemon/nextbsd-gnustep-apps.git /private/tmp/nextbsd-gnustep-apps
   cd /private/tmp/nextbsd-gnustep-apps
   ./install-apps.sh
   ```

4. Log out, log in as root, and turn on the [login window](#booting-to-the-login-panel) from this repository's folder:

   ```sh
   ./enable-loginwindow.sh
   ```

   The login panel replaces the text console straight away, and the machine boots to it from then on. Log in as your user, and the session starts InnerSpace, the Dock and Workspace.

Step 4 comes last because the login panel takes the console at once, and there is no switching to another console while it's up. If you enable it before step 3, run `install-apps.sh` over SSH, then log out of the desktop (or reboot) and log in again.

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

Each script clones and builds the core libraries into `/System/Library`. It can be re-run. Existing clones are updated to the latest commit on their default branch, and the script stops at the first failure.

### Core libraries

Built in this order, because each needs the ones before it:

| Library | What it is |
|---|---|
| tools-make | gnustep-make, with the `gershwin` filesystem layout |
| libobjc2 | Objective-C runtime |
| libs-base | Foundation |
| libs-corebase | Core Foundation |
| libs-gui | AppKit |
| libs-back | X11 drawing backend, using cairo, and gpbs. Built from NextBSD's fork, [nextbsd/libs-back](https://github.com/nextbsd/libs-back): upstream plus NextBSD fixes |
| libs-av | Audio and video, using FFmpeg |

The stock script builds libdispatch first, before tools-make.

Sources are cloned into `/Developer/Sources`.

## WindowServer

[WindowServer](https://github.com/nextbsd/apps-windowserver) is a native NextBSD display server, in the style of macOS's. GNUstep apps draw their own windows and WindowServer composites them, with no X11 in between. Apps talk to it through the `nextbsd` backend, which comes from a fork of libs-back, [nextbsd/libs-back](https://github.com/nextbsd/libs-back). It installs as `libgnustep-nextbsd` beside the stock X11 backend, and the `GSBackend` default picks one. libs-base and libs-gui are unchanged.

### Build

After `build-core-libs-nextbsd-dispatch.sh`, run this as root:

```sh
./build-windowserver.sh
```

It needs NextBSD's Mach-enabled libdispatch, so it won't run on the stock-libdispatch setup. It clones both repositories into `/Developer/Sources`. The fork goes into `libs-back-nextbsd`, apart from the stock `libs-back`. It installs:

| What | Where |
|---|---|
| WindowServer | `/System/Library/CoreServices/WindowServer` |
| `nextbsd` backend | `/System/Library/Bundles/libgnustep-nextbsd-032.bundle` |
| Client library and headers | `/usr/lib/libWindowServerClient.*`, `/usr/include/WindowServer` |
| `ws-session`, `wstest`, `wsctl` | `/usr/libexec/WindowServer` |
| LaunchDaemon (disabled) | `/System/Library/LaunchDaemons/org.nextbsd.WindowServer.plist` |

### Trying it without stopping X

Headless mode draws into memory instead of the screen, so it runs over SSH while X keeps the display. As root:

```sh
/usr/libexec/WindowServer/ws-session start --headless 1280x800
```

Then, as your user, point GNUstep apps at it and start one:

```sh
defaults write NSGlobalDomain GSBackend libgnustep-nextbsd
openapp Terminal.app &
/usr/libexec/WindowServer/wsctl list
/usr/libexec/WindowServer/wsctl snapshot /tmp/screen.ppm
```

`wsctl` can also click and type into the session: `wsctl click X Y`, `wsctl key a`. Stop the server with `ws-session stop` as root.

`GSBackend` in `NSGlobalDomain` applies to every GNUstep app you start, including in an X session. Remove it when you're done:

```sh
defaults delete NSGlobalDomain GSBackend
```

### Trying it on the display

1. Quit your X session.
2. On a text console, as root, run `/usr/libexec/WindowServer/ws-session`. It takes over the screen until you press Ctrl-C. `Ctrl+Alt+Backspace` also stops it. There is no switching to other consoles while it runs.
3. From SSH or another console, as your user, set `GSBackend` as above and start apps with `openapp`.

Terminal, Workspace, InnerSpace and the Dock (DockWM) run on it, and so does XLibre.app, which runs X11 programs on it rootless, as XQuartz does on macOS ([apps-xlibre](https://github.com/nextbsd/apps-xlibre)).

### Booting to the login panel

`build-windowserver.sh` also builds [loginwindow](https://github.com/nextbsd/apps-loginwindow), the graphical login, but doesn't turn it on. As root:

```sh
./enable-loginwindow.sh
```

The login panel replaces the text console straight away, and the machine boots to it from then on. Log in, and your session starts InnerSpace, the Dock and Workspace; quitting Workspace logs you out and brings the panel back. To go back to the text console:

```sh
./disable-loginwindow.sh
```

`enable-loginwindow.sh` enables WindowServer's LaunchDaemon with `launchctl load -w`, and copies loginwindow's plist from the app into `/System/Library/LaunchDaemons` and loads it. An installed `org.nextbsd.loginwindow.plist` tells NextBSD that a graphical login owns the console, so getty stays off `ttyv0` and console automatic login stands down.

## Uninstall

Run this as root:

```sh
./uninstall-core-libs.sh
```

It's a shell version of the `uninstall` target in [gershwin-developer's Makefile](https://github.com/gershwin-desktop/gershwin-developer/blob/main/Makefile). On NextBSD it removes `/System/Applications` and everything in `/System/Library` except `Caches`, `CoreServices`, `Extensions`, `Filesystems`, `LaunchAgents` and `LaunchDaemons`. NextBSD's base packages install into all of those except `Caches`. The Makefile keeps only `Caches`, `Extensions` and `LaunchDaemons`; the other three were added for NextBSD. It also removes WindowServer's files, which sit in those shared folders and in `/usr`. It also removes the sources in `/Developer/Sources` and the link-only symlinks in `/Developer/Link`.

## Guide

These scripts automate a wiki guide, which explains why each flag is there:

- [Building GNUstep core libraries on NextBSD](https://github.com/pkgdemon/pkgdemon.github.io/wiki/Building-GNUstep--Core-Libraries-on-NextBSD), whose [Backup: stock libdispatch](https://github.com/pkgdemon/pkgdemon.github.io/wiki/Building-GNUstep--Core-Libraries-on-NextBSD#backup-stock-libdispatch) section is the stock script
