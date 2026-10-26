# Hyprland scripts

The scripts behind my Hyprland setup: profiles, the settings panel, theming, bars and a pypr fix.

## How it's laid out

A style is just a folder. Drop in a new one and it works.

```
hypr/<style>/base/          shared .lua config
hypr/<style>/<variant>/     per-machine overrides (desktop, laptop...), incl. machine.lua
hypr/<style>/utilities/     quickshell utilities
hypr/<style>/waybar/<name>/ waybar styles (config, style.css, preview.png)
```

A variant file with the same name as a base file replaces it.

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

## pypr

Upstream pypr dies when Hyprland drops its IPC socket during a reload. Two files deal with it:

- `pypr.py`: installed as `~/.local/bin/pypr`, patches the bug at runtime so `/usr/lib` stays untouched.
- `pypr.sh`: restarts the daemon if it dies anyway. It stops when Hyprland does.
