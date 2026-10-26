# Hyprland scripts

The scripts behind my Hyprland setup: profiles, the settings panel, theming, bars and a pypr fix.

## How it's laid out

A style is just a folder. Drop in a new one and it works.

```
hypr/<style>/base/          shared .lua config
hypr/<style>/<variant>/     per-machine overrides (desktop, laptop...), incl. machine.lua
hypr/<style>/utilities/     quickshell utilities
hypr/<style>/waybar/<name>/ waybar styles (config, style.css, preview.png)
hypr/<style>/quickshellbar/<name>/  quickshell bar styles (config.json, preview.svg)
hypr/tweaks/                tweaks and saved profiles from the settings panel
```

A variant file with the same name as a base file replaces it.

`hyprland.lua` loads `machine`, `startup`, `style`, `shortcuts`, `hyprglass` and then `overrides.lua` last. `overrides.lua` applies `settings.lua` (only the keys you changed) on top of the profile:

- plugin keys go to hyprglass, not `hl.config`, and get retried at startup if the plugin isn't loaded yet
- layer glass has two switches, quickshell layers and everything else, turned into hyprglass `namespaces` / `exclude_namespaces`
- glass look values extend the preset from `hyprglass.lua` and get copied into `dark`/`light` too, otherwise those win
- animations use one curve for every leaf, base speeds divided by the speed multiplier
- mouse sensitivity is also set per device since per-device beats the global value

`utilities/<name>` are symlinks into the active style's `utilities/`. `shells.sh` rebuilds them on every start, so a utility that came in with a pull shows up without reapplying the profile.

## Profiles

```
hypr-profile.sh apply <style> <variant> [--offline]
hypr-profile.sh list
save-profile.sh        # save the live config back into the active profile
```

`save-profile.sh` sends `machine.lua` and anything the variant already overrides to the variant folder. Everything else goes to `base/`.

## Settings panel

`hypr-settings.py` is the backend. Tweaks live in `hypr/tweaks/<Style>-<variant>.json` and the active one is mirrored to `hypr/settings.lua`. Profile files are never touched.

```
hypr-settings.py state KEY...       # current values as JSON
hypr-settings.py set KEY=JSON ...   # save + apply live (dotted keys, null removes)
hypr-settings.py reset              # back to Default, variant file is kept
hypr-settings.py sync               # write settings.lua for the active profile
hypr-settings.py saved save NAME    # snapshot what's live
hypr-settings.py saved apply|delete ID
hypr-settings.py saved wipe         # delete all saved profiles and tweaks files
```

The live entry is one of:

- `default`: no overrides
- `variant:NAME`: `tweaks/<Style>-NAME.json`
- `saved:NAME`: `tweaks/saved/<Style>-<variant>/NAME.json`

Editing while on Default writes to the active variant's file and makes that live. The current entry is tracked in `hypr/.active-saved.json`.

An entry can also carry a color theme, bar, bar style and wallpaper. Changing those from the picker or the scripts records them on the live entry. `sync` also writes which bar runs (`hypr/.active-bar`, gitignored), so a fresh install starts the bar the entry names.

The panel itself (`Modern/utilities/settings`) is a sheet from the left (`ALT+S`). `Store.qml` holds the state and batches writes to `hypr-settings.py`. Every page and option is in `Schema.js`, keyed by dotted paths into the tweaks file:

- `config.*`: `hl.config()` options, live values from `hyprctl getoption`
- `glass.*`: hyprglass preset values, layered by `overrides.lua`
- `hyprglass.layers` / `hyprglass.quickshell`: which layers get glass
- `animation.*`, `border.*`, `cursor.*`, `boot.*`: read by `overrides.lua` / `startup.lua`

Adding an option is one line in `Schema.js`. 5+ choices turn into a dropdown. `when` hides a control unless another option has a value and `cap` hides it unless the hardware has it. Right-click resets a setting to the profile value.

## Theming

```
color-apply.sh [theme] [wallpaper]   # "pywal" (default) or a scheme from ~/.config/wal/colorschemes/
wallpaper-apply.sh                   # set wallpaper + regenerate theme
wallpaper-index.py                   # build the picker thumbnails/palettes
waybar-style.sh apply <name> | list
```

## Bars, utilities, OSD

```
bar.sh start | apply waybar|quickshell | style <name> | toggle | current
shells.sh start|stop|restart
shells.sh <utility> [call]           # home, launcher, music, wallpaper, settings
osd.sh vol-up|vol-down|vol-mute|mic-mute|bright-up|bright-down|caps|play|next|prev
```

All quickshell utilities run in one process (`shell.qml`), stay hidden and open over IPC. `boot` is the exception, `startup.lua` runs it alone. `ALT+a` toggles the bar.

Windows stay mapped with an empty input region while closed so they open instantly. Most of them take input over the whole screen while open so clicking outside closes them.

`common/Theme.qml` is shared by everything: pywal palette (`color9` accent, `color7` text), Hyprland's rounding, and its animation curve and speed so the utilities move like windows. The "default quickshell animations" setting gives them their own curve instead.

- **launcher** (tap `Super`): Home dial (Home/Settings/Wallpaper pinned, the rest by use, logout/reboot/poweroff need a second press), app grid ranked by use, every bash command on a wheel (`.bashrc` aliases and functions too), and keybinds parsed from `shortcuts.lua`. A trailing `-- text` on a bind in `shortcuts.lua` is used as its description. `launcher.py` gives it the desktop entry info quickshell doesn't expose and keeps the usage counts.
- **home-screen** (`ALT+Tab`): also the notification daemon, so it's always running. Popups go bottom left and hide while the home screen is open. Other monitors get a dimmed wallpaper and a clock.
- **music** (`ALT+Enter`): card under the bar. Follows Spotify, else whatever is playing. Never grabs the keyboard, click it first. Drag the bottom edge to resize, drag anywhere else to move, double-click to put it back. It publishes where it is so the launcher and bar can work around it.
- **wallpaper-picker** (`ALT+W`): previews the wallpaper full screen on every monitor and recolors both bars live. Waybar only watches `style.css`, so that gets rewritten in place. Thumbnails, screen-sized copies and palettes come from `wallpaper-index.py`, which reruns when the library changes. The theme chips are on their own layer (`wallpaper-picker-tab`) so hyprglass can glass them.
- **osd**: `osd.sh` does the action and then shows it.
- Spotify always opens through `common/spotify.sh`: its pypr scratchpad if pypr is running, a normal window otherwise.

### Quickshell bar

`Modern/utilities/bar` is the other bar next to waybar. `bar.sh` picks which one runs. Modules go into up to three pills like waybar's left/center/right. Hovering a module grows its pill into a card with that module's page, and moving to another module on the same pill swaps the page without closing it.

- `Module.qml`: `user`, `workspaces`, `media`, `date`, `constdate`, `timer`, `clock`, `tray`, `updates`, `network`, `audio`, `battery`, `power`, and `|` for a divider. `media` and `updates` hide when empty.
- `Island.qml`: the media/clock page, with tabs for media, a focus timer, the color picker and weather (wttr.in). The timer and weather live in the shell so every monitor shares them.
- `Menus.qml`: network (Wi-Fi and Bluetooth), audio, power and tray menus.
- `Workspaces.qml`: the dots, the workspace page and the `Super+Tab` overview. Hyprland is only polled while one of those is showing.

A style is `quickshellbar/<name>/config.json` (`hypr/.quickshell-bar` names the active one): `left`/`center`/`right` modules (only `center` gives one big pill), `strip` (a full-width strip the cards grow out of), `background`, `attached` (pills hang from the top edge), `height`, `gap` and `shape` (`round`, `capsule`, `square`).

The surface is one fixed size, tall enough for the biggest card, so it never resizes and redraws its blur. If a card would cover the music player, the player tucks away until it closes.

`InstallScripts/quickshellbarinstall.sh` and `waybarinstall.sh` install either bar on its own. The standalone quickshell bar reads `style.json` next to its `shell.qml` instead.

### Lock

`lock.sh` runs `utilities/lock` in its own process, not the shared one, so it still comes up if that one is down. It quits after unlocking. `lock.sh --preview` shows it in windows without locking.

It takes a frame of each monitor with grim first and fades from that into the blurred wallpaper. On unlock, handoff layers that were mapped under the lock the whole time take over the backdrop and fade into the desktop. Quickshell only loads files under the folder it started in, so `Lock.qml` has its own copy of the theme. Gear menu settings are saved in `~/.local/state`. It ships its own pam file so it doesn't need hyprlock's.

If it crashes the session stays locked. Switch to a tty and run `lock.sh` again.

## pypr

Upstream pypr dies when Hyprland drops its IPC socket during a reload. Two files deal with it:

- `pypr.py`: installed as `~/.local/bin/pypr`, patches the bug at runtime so `/usr/lib` stays untouched.
- `pypr.sh`: restarts the daemon if it dies anyway. It stops when Hyprland does.
