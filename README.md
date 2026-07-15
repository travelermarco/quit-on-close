# QuitOnClose

By default, macOS keeps an application running even after you close its last
window with the red button: it stays "alive" in the background until you
press `Cmd+Q`. On Windows, closing the last window closes the program too.

**QuitOnClose** brings that Windows behaviour to macOS: when you close an
app's last window, the app actually quits — no more windows to keep track
of, no more `Cmd+Q` to remember.

It's not an app with windows or menus: it runs silently in the background,
with no Dock icon and no menu bar item. Nothing changes visually — the only
difference you'll notice is that closing the last window also closes the
program, just like on Windows.

## How it works

QuitOnClose uses the macOS Accessibility API (the same one VoiceOver and
window-management utilities use) to observe window creation and destruction
for every "regular" application (i.e. every app with a Dock icon).

When a window closes, QuitOnClose checks whether it was that app's last
remaining window. If so, it asks the app to quit
(`NSRunningApplication.terminate()` — the exact same signal as `Cmd+Q`), so
if there are unsaved documents the app still shows its normal "Do you want
to save changes?" dialog.

Things that **don't** happen:
- minimizing a window (yellow button) does not quit the app;
- background apps with no Dock icon (menu-bar-only agents, utilities) are
  never touched — they're automatically excluded;
- Finder is excluded by default (see below).

## Requirements

- macOS 13 (Ventura) or later
- Xcode Command Line Tools (to build): `xcode-select --install`
- **Accessibility** permission granted to the app (required: macOS won't let
  any app observe another app's windows without it)

## Installation

```bash
./Scripts/build.sh      # builds dist/QuitOnClose.app
./Scripts/install.sh    # copies it to /Applications and registers login auto-start
```

On first run, macOS will ask for Accessibility permission. Go to:

**System Settings → Privacy & Security → Accessibility**

and enable **QuitOnClose**. If the system prompt doesn't appear on its own:

```bash
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
```

Until the permission is granted, QuitOnClose stays idle (it won't quit
anything): it checks every couple of seconds and activates automatically as
soon as you grant it, no restart needed.

QuitOnClose starts itself at every login (via a LaunchAgent) and never shows
up in the Dock or the menu bar.

## Excluding apps

Some apps (e.g. Finder) are better left always running. The exclusion list
lives at:

```
~/Library/Application Support/QuitOnClose/excluded-bundle-ids.txt
```

One bundle identifier per line (`com.apple.finder` is excluded by default).
To find an app's bundle identifier:

```bash
osascript -e 'id of app "Mail"'
```

Add the ID to the list, then restart QuitOnClose:

```bash
launchctl kickstart -k gui/$(id -u)/com.travelermarco.quitonclose
```

## Logs

```
~/Library/Logs/QuitOnClose.log
```

## Uninstalling

```bash
./Scripts/uninstall.sh
```

Removes the LaunchAgent and the app from `/Applications`. Remember to also
remove QuitOnClose from the Accessibility list in System Settings if you no
longer need it.

## Known limitations

- Some apps briefly destroy and recreate a window during certain transitions
  (e.g. entering/exiting full screen). QuitOnClose waits ~350ms before
  re-checking that the window count is really zero, specifically to avoid
  false positives in these edge cases.
- Apps must expose their windows through the standard Accessibility API
  (virtually every native macOS app does).
