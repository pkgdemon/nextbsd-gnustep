# nextbsd-gnustep

Scripts that build the GNUstep core libraries and a desktop of GNUstep apps on NextBSD, using only NextBSD packages.

The libraries are stock upstream sources, from the latest commit on each default branch. Nothing is pinned, so what you build changes as upstream does. libdispatch and the blocks runtime come from the NextBSD base system.

## Scripts

Run them in this order:

| Script | Run as | What it does |
|---|---|---|
| `install-packages.sh` | root | Installs the NextBSD packages |
| `build-core-libs.sh` | root | Clones and builds the core libraries into `/System/Library`, installs DejaVu fonts, and runs the check |
| `install-apps.sh` | normal user | Builds the apps and theme into your home folder and turns on the theme |

`check-core-libs.sh` runs the post-install checks on its own and changes nothing.

All of them can be re-run. Existing clones are updated with `git pull --ff-only`, and the script stops at the first failure.

```sh
# as root
./install-packages.sh
./build-core-libs.sh

# as your normal user
./install-apps.sh
```

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

### Apps

| Repository | What it provides |
|---|---|
| [nextbsd-theme](https://github.com/pkgdemon/nextbsd-theme) | The NextBSD dark theme, its icons and fonts |
| [apps-terminal](https://github.com/pkgdemon/apps-terminal) | Terminal, with colors the theme can set |
| [Finder](https://github.com/pkgdemon/Finder) | FileViewer |
| [apps-dock](https://github.com/pkgdemon/apps-dock) | The Dock (`DockWM.app`) |
| [apps-innerspace](https://github.com/pkgdemon/apps-innerspace) | InnerSpace, a live desktop background |
| [gnustep-windowmanager](https://github.com/pkgdemon/gnustep-windowmanager) | Optional title bars for plain X11 programs |

Repositories are cloned into your home folder. Apps install to `~/Applications`, the theme to `~/Library/Themes`, and its fonts to `~/Library/Fonts`.

`nextbsd-theme` is a private repository cloned over SSH, so the user running `install-apps.sh` needs a GitHub SSH key with access to it.

WindowManager is only built with `./install-apps.sh --with-windowmanager`. You only need it for programs that aren't GNUstep apps, such as `xterm`.

## Session setup

The scripts don't touch your shell or X session files. Create these two yourself.

### `~/.zprofile`

```sh
source /System/Library/Makefiles/GNUstep.sh
export LIBRARY_PATH=/usr/X11/lib:/Developer/Link
export CPATH=/usr/X11/include
export GNUSTEP_INSTALLATION_DOMAIN="USER"
```

Log in again after creating it.

### `~/.xinitrc`

```sh
. /System/Library/Makefiles/GNUstep.sh

openapp DockWM.app &
DOCK_PID=$!
sleep 1

openapp FileViewer.app

kill $DOCK_PID
```

FileViewer runs in the foreground, so quitting it ends the session.

## Using the desktop

Start it with `startx`.

In the Dock's settings, turn on the common tile option so the Dock uses the theme's dark tile.

To go back to the default look, run `defaults write NSGlobalDomain GSTheme GNUstep` and reopen your apps.

Open `InnerSpace.app` from FileViewer or the Dock. It runs as a live background behind your other windows, and its **Run** menu item starts the full-screen saver. It loads modules from `~/Library/InnerSpace`, not `~/Library/Bundles`.

Start WindowManager when you need it with `openapp WindowManager.app`, and leave it out of `.xinitrc`. Stop it with `pkill -x WindowManager`.

## Known limitations

- FileViewer copies and recursively deletes folders through `/proc/self/fd/...`, and NextBSD has no `/proc`. Expect those two operations to fail.
- Translucency needs a compositor that honors window opacity, so it isn't available in this setup.
- Theme icons are normal resolution, and may look soft at 2× display scaling.

## Guides

These scripts automate two wiki guides, which explain why each flag is there:

- [Building GNUstep core libraries on NextBSD](https://github.com/pkgdemon/pkgdemon.github.io/wiki/Building-GNUstep--Core-Libraries-on-NextBSD)
- [Building GNUstep apps on NextBSD](https://github.com/pkgdemon/pkgdemon.github.io/wiki/Building-GNUstep-Apps-on-NextBSD)
