hypr-settomgs.py

"""Backend for the Hyprland settings panel.

Every style/variant keeps its own tweaks in hypr/tweaks/<Style>-<variant>.json (source of truth). The
active one is mirrored to hypr/settings.lua, which overrides.lua layers over the profile. Profile files
are never edited, and switching profile swaps in that profile's own tweaks.

  hypr-settings.py state KEY...      current values + profiles, themes and cursors, as JSON
  hypr-settings.py set KEY=JSON ...  save and live-apply (KEY is a dotted path, e.g. config.general.gaps_in;
                                     a JSON null removes the key)
  hypr-settings.py reset             switch to Default (no overrides); the variant's file is kept
  hypr-settings.py sync              write settings.lua for the active profile (used when switching)
  hypr-settings.py cursor            apply the active profile's cursor theme and size
  hypr-settings.py appearance        apply the live entry's color theme and waybar style if they differ
  hypr-settings.py ui KEY=JSON ...   panel UI state (width, last page), kept outside the repo
  hypr-settings.py saved save NAME   snapshot what is live now as a named saved profile
  hypr-settings.py saved apply ID    make an entry the live one (ids below)
  hypr-settings.py saved delete ID   remove an entry's file; Default can't be deleted
  hypr-settings.py saved wipe        remove every saved profile and every tweaks file (style folders are untouched)

The live settings come from one entry per style/variant, picked on the panel's profile page:
  default        no overrides at all: the profile's own Hyprland files as they are
  variant:NAME   tweaks/<Style>-NAME.json, one per variant of the style (desktop, laptop, ...)
  saved:NAME     tweaks/saved/<Style>-<variant>/NAME.json, named snapshots in the same format
Edits land in the live entry and it stays live. On Default there is nothing to edit, so the change is added
to the active variant's own file (Desktop/Laptop) and that becomes live. Which entry is live is kept in
hypr/.active-saved.json.

Besides Hyprland options an entry carries colors.theme, bar.kind, waybar.style, quickshell.style and wallpaper.path; left
out they mean pywal, waybar, the style's "default" looks for either bar and whatever wallpaper is up, which is what
Default gets.
"""

hypr-profile.sh

# Activates a Hyprland profile: hypr/<style>/base/*.lua plus hypr/<style>/<variant>/*.lua become the active
# config (a variant file named like a base file replaces it), and hypr/<style>/utilities/* become the active
# quickshells (symlinked into hypr/utilities/).
# Adding a style is just a new folder: <style>/base/, <style>/utilities/ and a <style>/<variant>/machine.lua
# per machine (monitors, input, boot and cursor defaults).
#
# usage: hypr-profile.sh apply <style> <variant> [--offline]
#        hypr-profile.sh list

color-apply.sh

# Regenerates the desktop palette. Theme "pywal" (the default) derives it from the wallpaper;
# anything else is a scheme from ~/.config/wal/colorschemes/<dark|light>/<name>.json.
# usage: color-apply.sh [theme] [wallpaper]   (theme "" keeps the saved one)

bar.sh

# Which bar is up: waybar, or the quickshell bar (utilities/bar, hosted by shells.sh like the other utilities).
# The choice is kept in hypr/.active-bar; the quickshell bar watches that file and shows or hides itself.
#   bar.sh start                       (re)start the chosen bar (startup.lua, profile switches)
#   bar.sh apply waybar|quickshell     switch to it now; remembered by the live profile entry
#   bar.sh style <name>                the quickshell bar's style: hypr/<style>/quickshellbar/<name>/, like waybar-style.sh
#   bar.sh toggle                      stop the chosen bar, or start it again (ALT+a)
#   bar.sh current                     print the chosen bar
#   bar.sh <call> [args...]            IPC call into the quickshell bar (menu, island, overview, close)

osd.sh

# Applies a volume/brightness/caps/media action, then shows it on the Quickshell OSD.
# usage: osd.sh vol-up|vol-down|vol-mute|mic-mute|bright-up|bright-down|caps|play|next|prev

pypr.py

"""pypr with runtime fixes for Hyprland dropping its IPC socket mid plugin load.

Installed as ~/.local/bin/pypr (ahead of /usr/bin on PATH), so both the daemon and
`pypr toggle ...` clients go through it. Patches at runtime instead of editing
/usr/lib, so pyprland updates keep working.

Upstream bug: hyprctl_connection's cleanup raises OSError(107) from wait_closed(),
masking the ConnectionResetError, so retry_on_reset never retries; the error
notification then fails the same way and kills the daemon.
"""

pypr.sh

# Keeps the pypr daemon alive. Upstream pypr dies when Hyprland drops its IPC socket mid-reload
# (hyprpm reload, plugin loads). pypr.py patches that; this is the fallback for anything
# else, since pypr exits 0 even on a crash.
# Stops once Hyprland itself is gone. flock keeps a single supervisor per session.

save-profile.sh

# Save the live root config back into the active profile.
# Reads .active-profile (e.g. "Modern/laptop"). machine.lua, and any file the variant already overrides,
# go back to the variant folder; every other .lua file goes to the style's shared base/.

shell.qml

// Hosts every utility in one qs process, so the Qt/QML engine is loaded once instead of once per
// utility. A utility is any folder here with a shell.qml, so adding one is just adding the folder
// (hypr-profile.sh links the active style's folders in). boot is left out since startup.lua runs it alone.

shells.sh

# The quickshell utilities, all hosted in one process by utilities/shell.qml.
#   shells.sh start|stop|restart                         the shared process
#   shells.sh <utility> [call [args...]]                 IPC call into a utility (call defaults to toggle):
#     shells.sh home | launcher | music | wallpaper | settings
#     shells.sh launcher tab apps|home|commands|keybinds  open the launcher on that tab
#     shells.sh music open|close
#     shells.sh osd notify <kind> <value> <flag> <text>   (osd.sh does this)
# Utilities stay resident and hidden, so opening one is an IPC call rather than a launch. If the process
# isn't up yet it is started first, and a toggle becomes an open.
# boot is excluded: it only runs once, launched by startup.lua with its own environment.

wallpaper-index.py

"""Builds the wallpaper picker index: thumbnails plus a pywal palette per image, cached."""

wallpaper-apply.sh

# Applies a wallpaper and regenerates the theme (pywal, or the scheme chosen in the settings panel).

waybar-style.sh

# Waybar styles belong to a Hyprland style: hypr/<style>/waybar/<name>/{config,style.css,preview.png}.
# Adding one is just a new folder.
#   waybar-style.sh apply <name>    install it as the live waybar config and restart waybar
#   waybar-style.sh list            names available for the active style