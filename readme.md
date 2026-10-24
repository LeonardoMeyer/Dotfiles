[![Typing SVG](https://readme-typing-svg.demolab.com?font=Fira+Code&size=30&letterSpacing=tiny&duration=2000&pause=3000&color=F7F7F7&center=true&vCenter=true&width=435&lines=Eli's+Dotfiles)](https://git.io/typing-svg)

<p align="center">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/rice-default.png" width="32%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/rice-glass.png" width="32%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/rice-zen.png" width="32%">
</p>
<p align="center">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/rice7.png" width="32%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/rice1.png" width="32%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/rice4.png" width="32%">
</p>
<p align="center">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/rice5.png" width="32%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/rice6.png" width="32%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/rice3.png" width="32%">
</p>

> [!TIP]
> Check out [MyFetch](https://github.com/elifouts/MyFetch) now!

My **Arch** Linux dotfiles for a clean, lightweight **Hyprland** setup built around **Quickshell**.

Claude helped with some of the scripting and docs. The design, look, and tweaking are all mine.

***ENJOY!!***

-Eli F.


> [!WARNING]
> Everything is designed to work with `Pywal`.
>
> <details>
>   <summary><picture><img src="images/badges/color-schemes-more-info-v2.svg" alt="Color Schemes (more info)" align="absmiddle"></picture></summary>
>
>   Don't want `Pywal`? Pick a fixed color scheme in **Settings → Colors**, or replace the colors in an app's `style.css`. I highly recommend `Pywal` though!
>
> </details>

<p align="center">
  <img src="https://github.com/elifouts/Dotfiles/blob/main/images/v2/profiles.gif" width="50%">
</p>

# Install

<details>
  <summary><picture><img src="images/badges/arch-install-script-v2.svg" alt="Arch Install Script" align="absmiddle"></picture></summary>

  ```
  cd && git clone https://github.com/elifouts/Dotfiles.git
  cd ~/Dotfiles/InstallScripts
  chmod +x install.sh
  ./install.sh
  ```

  - `1. Full install`: everything.
  - `2. Waybar` or `3. Quickshell bar`: just a bar, no other dotfiles needed.

  Nothing gets deleted. It offers to back up `~/.config` first, and anything it replaces is moved to `~/.dotfiles_replaced_<date>`. Configs are symlinked to `~/Dotfiles`, so `git pull` updates them.
</details>

<details>
  <summary><picture><img src="images/badges/package-manager-tui-v2.svg" alt="Package Manager TUI" align="absmiddle"></picture></summary>

  Lists installed packages with their source and size.

  ```bash
  ~/Dotfiles/.config/hypr/utilities/package-tui.sh
  ```

  `j`/`k` scroll, `d` uninstall, `r` reinstall, `q` quit.
</details>

## Styles, Variants & Profiles

<details>
  <summary><picture><img src="images/badges/how-it-all-fits-together-v2.svg" alt="How It All Fits Together" align="absmiddle"></picture></summary>

  - **Style**: the whole look. Right now there is one: `Modern`.
  - **Variant**: `desktop` or `laptop` (monitors, input, defaults).
  - **Profile**: your tweaks on top, picked in the settings panel. **Glass** and **Zen** are mine. A saved profile also remembers your colors, bar and wallpaper.

  ![profiles](https://github.com/elifouts/Dotfiles/blob/main/images/v2/profiles.gif)

  ```
  hypr/
    Modern/                 <- a style
      base/                 <- shared hyprland config
      laptop/  desktop/     <- variants
      utilities/            <- quickshells
      waybar/<name>/        <- waybar styles
      quickshellbar/<name>/ <- quickshell bar styles
    tweaks/                 <- your tweaks and saved profiles
  ```
</details>

## My Applications

Screenshots are shown as **Default** | **Glass** | **Zen**.

<details>
  <summary><picture><img src="images/badges/quickshell-v2.svg" alt="Quickshell" align="absmiddle"></picture></summary>

  All of my widgets are [Quickshell](https://quickshell.org) shells. They follow your `Pywal` colors and open on the monitor you're using.

  ### *How To Install*
  1. `yay -S quickshell`
  2. Copy `Dotfiles/.config/hypr` into `~/.config` (or use the installer)
  3. `~/.config/hypr/utilities/shells.sh start` (already in `startup.lua`)
</details>

<details>
<summary><picture><img src="images/badges/launcher-v2.svg" alt="Launcher" align="absmiddle"></picture></summary>
<img src="https://github.com/elifouts/Dotfiles/blob/main/images/v2/launcher-default.png" width = "33%"><img src="https://github.com/elifouts/Dotfiles/blob/main/images/v2/launcher-glass.png" width = "33%"><img src="https://github.com/elifouts/Dotfiles/blob/main/images/v2/launcher-zen.png" width = "33%">

![launcher](https://github.com/elifouts/Dotfiles/blob/main/images/v2/launcher.gif)

**Tap `Super`**. Session dial, app search, commands and a list of every keybind.
</details>

<details>
<summary><picture><img src="images/badges/home-screen-v2.svg" alt="Home Screen" align="absmiddle"></picture></summary>
<img src="https://github.com/elifouts/Dotfiles/blob/main/images/v2/home-default.png" width = "33%"><img src="https://github.com/elifouts/Dotfiles/blob/main/images/v2/home-glass.png" width = "33%"><img src="https://github.com/elifouts/Dotfiles/blob/main/images/v2/home-zen.png" width = "33%">

**`Alt+Tab`**. Clock, music, calendar, system stats, volume and notifications.
</details>

<details>
<summary><picture><img src="images/badges/settings-panel-v2.svg" alt="Settings Panel" align="absmiddle"></picture></summary>
<img src="https://github.com/elifouts/Dotfiles/blob/main/images/v2/settings-default.png" width = "33%"><img src="https://github.com/elifouts/Dotfiles/blob/main/images/v2/settings-glass.png" width = "33%"><img src="https://github.com/elifouts/Dotfiles/blob/main/images/v2/settings-zen.png" width = "33%">

![settings](https://github.com/elifouts/Dotfiles/blob/main/images/v2/settings.gif)

**`Alt+S`**. Change profiles, bar, colors, windows, effects, animations, input and more. Everything applies live.

- Save a profile in **Profile → Saved profiles**.
- **Right-click** any setting to reset it.
</details>

<details>
<summary><picture><img src="images/badges/music-player-v2.svg" alt="Music Player" align="absmiddle"></picture></summary>
<img src="https://github.com/elifouts/Dotfiles/blob/main/images/v2/music-default.jpg" width = "33%"><img src="https://github.com/elifouts/Dotfiles/blob/main/images/v2/music-glass.jpg" width = "33%"><img src="https://github.com/elifouts/Dotfiles/blob/main/images/v2/music-zen.jpg" width = "33%">

![music](https://github.com/elifouts/Dotfiles/blob/main/images/v2/music.gif)

**`Alt+Enter`**. Controls Spotify or whatever is playing, with a `cava` visualizer.
</details>

<details>
<summary><picture><img src="images/badges/wallpaper-picker-v2.svg" alt="Wallpaper Picker" align="absmiddle"></picture></summary>
  
![wallpaper-picker](https://github.com/elifouts/Dotfiles/blob/main/images/v2/wallpaper-picker.gif)

**`Alt+W`**. A carousel of `~/wallpapers/library`. Picking one updates the `Pywal` colors everywhere.
</details>

<details>
<summary><picture><img src="images/badges/osd-v2.svg" alt="OSD" align="absmiddle"></picture></summary>
<img src="https://github.com/elifouts/Dotfiles/blob/main/images/v2/osd-default.png" width = "33%"><img src="https://github.com/elifouts/Dotfiles/blob/main/images/v2/osd-glass.png" width = "33%"><img src="https://github.com/elifouts/Dotfiles/blob/main/images/v2/osd-zen.png" width = "33%">

![osd](https://github.com/elifouts/Dotfiles/blob/main/images/v2/osd.gif)

Pops up for volume, brightness, caps lock and media keys.
</details>

<details>
<summary><picture><img src="images/badges/notifications-v2.svg" alt="Notifications" align="absmiddle"></picture></summary>
<img src="https://github.com/elifouts/Dotfiles/blob/main/images/v2/notify-default.png" width = "33%"><img src="https://github.com/elifouts/Dotfiles/blob/main/images/v2/notify-glass.png" width = "33%"><img src="https://github.com/elifouts/Dotfiles/blob/main/images/v2/notify-zen.png" width = "33%">

![notify](https://github.com/elifouts/Dotfiles/blob/main/images/v2/notify.gif)

Popups in the bottom left. History is on the home screen.
</details>

<details>
<summary><picture><img src="images/badges/boot-animation-v2.svg" alt="Boot Animation" align="absmiddle"></picture></summary>
<img src="https://github.com/elifouts/Dotfiles/blob/main/images/v2/boot-default.png" width = "33%"><img src="https://github.com/elifouts/Dotfiles/blob/main/images/v2/boot-glass.png" width = "33%"><img src="https://github.com/elifouts/Dotfiles/blob/main/images/v2/boot-zen.png" width = "33%">

![boot](https://github.com/elifouts/Dotfiles/blob/main/images/v2/boot.gif)

Plays when Hyprland starts. Turn it off in **Settings → System**.
</details>

<details>
  <summary><picture><img src="images/badges/waybar-v2.svg" alt="Waybar" align="absmiddle"></picture></summary>

  ![waybar-default](https://github.com/elifouts/Dotfiles/blob/main/images/v2/waybar-default.png)
  ![waybar-glass](https://github.com/elifouts/Dotfiles/blob/main/images/v2/waybar-glass.png)
  ![waybar-zen](https://github.com/elifouts/Dotfiles/blob/main/images/v2/waybar-zen.png)

  A minimal Waybar with 4 styles (`default`, `experimental`, `line`, `zen`). Hover to expand hidden widgets. Pick a style in **Settings → Profile**, `Alt+A` reloads it.

  ### *How To Install*
  Run `InstallScripts/install.sh` → `2. Waybar`.

  Needs `waybar hyprpicker pywal blueman bluez networkmanager`.
</details>

<details>
  <summary><picture><img src="images/badges/quickshell-bar-v2.svg" alt="Quickshell Bar" align="absmiddle"></picture></summary>

  ![quickshellbar-default](https://github.com/elifouts/Dotfiles/blob/main/images/v2/quickshellbar-default.png)
  ![quickshellbar-attached](https://github.com/elifouts/Dotfiles/blob/main/images/v2/quickshellbar-attached.png)
  ![quickshellbar-experimental](https://github.com/elifouts/Dotfiles/blob/main/images/v2/quickshellbar-experimental.png)
  ![quickshellbar-full](https://github.com/elifouts/Dotfiles/blob/main/images/v2/quickshellbar-full.png)
  ![quickshellbar-zen](https://github.com/elifouts/Dotfiles/blob/main/images/v2/quickshellbar-zen.png)

  ![quickshellbar-attached](https://github.com/elifouts/Dotfiles/blob/main/images/v2/quickshellbar-attached.gif)

  A Quickshell bar with 5 styles (`default`, `attached`, `experimental`, `full`, `zen`). Its pills grow into cards for workspaces, media, network, sound and power (inspired by [NabyScape](https://github.com/BillyNabil/nabyscape)). Pick a style in **Settings → Profile**, `Alt+A` toggles it.

  ### *How To Install*
  Run `InstallScripts/install.sh` → `3. Quickshell bar`, then start it with `qs -c dotfiles-bar`.
</details>

<details>
  <summary><picture><img src="images/badges/lock-screen-v2.svg" alt="Lock Screen" align="absmiddle"></picture></summary>

  **`Mod+L`**, or after being idle. Blurs your wallpaper and shows a music card when something is playing.

  ### *How To Install*
  1. Install [Quickshell](https://quickshell.org/) and `hypridle`
  2. Copy `.config/hypr/Modern/utilities/lock` to `~/.config/hypr/utilities/lock`, plus `utilities/lock.sh` and `hypridle.conf`
</details>

<details>
  <summary><picture><img src="images/badges/nvim-v2.svg" alt="Nvim" align="absmiddle"></picture></summary>
<img src="https://github.com/elifouts/Dotfiles/blob/main/images/v2/nvim-default.png" width = "33%"><img src="https://github.com/elifouts/Dotfiles/blob/main/images/v2/nvim-glass.png" width = "33%"><img src="https://github.com/elifouts/Dotfiles/blob/main/images/v2/nvim-zen.png" width = "33%">

A lightweight Lazy setup with only the plugins I want, themed with `Pywal`. Relaunch it after changing wallpaper to load new colors.

### *How To Install*
1. `yay -S neovim`
2. Copy `Dotfiles/.config/nvim` into `~/.config/`
3. Start `nvim` and it installs everything.
</details>

<details>
  <summary><picture><img src="images/badges/starship-v2.svg" alt="Starship" align="absmiddle"></picture></summary>
  <img src="https://github.com/elifouts/Dotfiles/blob/main/images/v2/starship-default.png" width = "33%"><img src="https://github.com/elifouts/Dotfiles/blob/main/images/v2/starship-glass.png" width = "33%"><img src="https://github.com/elifouts/Dotfiles/blob/main/images/v2/starship-zen.png" width = "33%">

A minimal prompt with everything you need.

### *How To Install*
1. Install [Starship](https://github.com/starship/starship?tab=readme-ov-file#-installation)
2. Copy `Dotfiles/.config/starship.toml` into `~/.config`
3. Add `eval "$(starship init bash)"` to your `.bashrc` ([other shells](https://github.com/starship/starship?tab=readme-ov-file#step-2-set-up-your-shell-to-use-starship))
</details>

<details>
  <summary><picture><img src="images/badges/pywalfox-v2.svg" alt="Pywalfox" align="absmiddle"></picture></summary>
  <img src="https://github.com/elifouts/Dotfiles/blob/main/images/v2/fox-default.png" width = "33%"><img src="https://github.com/elifouts/Dotfiles/blob/main/images/v2/fox-glass.png" width = "33%"><img src="https://github.com/elifouts/Dotfiles/blob/main/images/v2/fox-zen.png" width = "33%">

Makes Firefox use your `Pywal` colors.

### *How To Install*
1. Install [Pywalfox](https://github.com/Frewacom/pywalfox) and run `pywalfox install`
2. Install the Pywalfox Firefox add-on
3. Run `pywalfox update` after changing colors
</details>

<details>
  <summary><picture><img src="images/badges/gtk-themes-v2.svg" alt="GTK Themes" align="absmiddle"></picture></summary>

  - Widgets: Materia-dark
  - Icons: Qogir-dark
  - Cursor: Bibata-Modern-Ice
</details>

<details>
  <summary><picture><img src="images/badges/old-stuff-no-longer-used-v2.svg" alt="Old Stuff (no longer used)" align="absmiddle"></picture></summary>

  Replaced by the Quickshell utilities. Configs are still in `archive/`.

<details>
  <summary><picture><img src="images/badges/wofi-replaced-by-the-launcher-and-wallpaper-picker-v2.svg" alt="Wofi (replaced by the Launcher and Wallpaper Picker)" align="absmiddle"></picture></summary>
    <img src="https://github.com/elifouts/Dotfiles/blob/main/images/wofi1.png" width = "35%"><img src="https://github.com/elifouts/Dotfiles/blob/main/images/wofi2.png" width = "35%"><img src="https://github.com/elifouts/Dotfiles/blob/main/images/wofi3.png" width = "35%"><img src="https://github.com/elifouts/Dotfiles/blob/main/images/wofi4.png" width = "35%">

  To blur Wofi:

  ```
  layerrule = blur, wofi
  layerrule = ignorezero, wofi
  layerrule = ignorealpha 0.5, wofi
  ```
</details>

<details>
  <summary><picture><img src="images/badges/swaync-replaced-by-notifications-and-the-home-screen-v2.svg" alt="Swaync (replaced by Notifications and the Home Screen)" align="absmiddle"></picture></summary>
  <img src="https://github.com/elifouts/Dotfiles/blob/main/images/swaync1.png" width = "20%"><img src="https://github.com/elifouts/Dotfiles/blob/main/images/swaync2.png" width = "20%"><img src="https://github.com/elifouts/Dotfiles/blob/main/images/swaync3.png" width = "20%"><img src="https://github.com/elifouts/Dotfiles/blob/main/images/swaync4.png" width = "20%">

  Config is in `archive/swaync`.
</details>

<details>
  <summary><picture><img src="images/badges/swayosd-replaced-by-the-osd-v2.svg" alt="SwayOSD (replaced by the OSD)" align="absmiddle"></picture></summary>

  Config is in `archive/swayosd`.
</details>

<details>
  <summary><picture><img src="images/badges/wlogout-replaced-by-the-launcher-s-home-dial-v2.svg" alt="Wlogout (replaced by the Launcher's Home dial)" align="absmiddle"></picture></summary>
  <img src="https://github.com/elifouts/Dotfiles/blob/main/images/wlogout1.png" width = "40%"><img src="https://github.com/elifouts/Dotfiles/blob/main/images/wlogout2.png" width = "40%"><img src="https://github.com/elifouts/Dotfiles/blob/main/images/wlogout3.png" width = "40%"><img src="https://github.com/elifouts/Dotfiles/blob/main/images/wlogout4.png" width = "40%">

  Config is in `archive/wlogout`.
</details>

<details>
  <summary><picture><img src="images/badges/hyprlock-v2.svg" alt="Hyprlock" align="absmiddle"></picture></summary>
  <img src="https://github.com/elifouts/Dotfiles/blob/main/images/v2/lock-default.png" width = "33%"><img src="https://github.com/elifouts/Dotfiles/blob/main/images/v2/lock-glass.png" width = "33%"><img src="https://github.com/elifouts/Dotfiles/blob/main/images/v2/lock-zen.png" width = "33%">

  ![lock](https://github.com/elifouts/Dotfiles/blob/main/images/v2/lock.gif)

  <img src="https://github.com/elifouts/Dotfiles/blob/main/images/lock1.PNG" width = "50%"><img src="https://github.com/elifouts/Dotfiles/blob/main/images/lock2.png" width = "50%"><img src="https://github.com/elifouts/Dotfiles/blob/main/images/lock3.png" width = "50%"><img src="https://github.com/elifouts/Dotfiles/blob/main/images/lock4.png" width = "50%">

  Replaced by the Quickshell lock screen. Config is in `archive/hyprlock`.
</details>

<details>
  <summary><picture><img src="images/badges/old-wallpaper-solution-wofi-swww-v2.svg" alt="Old Wallpaper Solution (wofi + swww)" align="absmiddle"></picture></summary>

  ![image](https://github.com/user-attachments/assets/7cbe58e3-7226-4537-8e69-bb316cdfaebc)

  Wofi + `swww` + `Pywal`.
</details>

</details>

<details>
<summary><picture><img src="images/badges/gallery-v2.svg" alt="Gallery" align="absmiddle"></picture></summary>

### Desktop Profiles

<p align="center">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/rice-default.png" width="32%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/rice-glass.png" width="32%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/rice-zen.png" width="32%">
</p>

### Quickshell

<p align="center">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/launcher-default.png" width="32%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/launcher-glass.png" width="32%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/launcher-zen.png" width="32%">
</p>
<p align="center">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/home-default.png" width="32%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/home-glass.png" width="32%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/home-zen.png" width="32%">
</p>
<p align="center">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/settings-default.png" width="32%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/settings-glass.png" width="32%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/settings-zen.png" width="32%">
</p>
<p align="center">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/music-default.jpg" width="32%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/music-glass.jpg" width="32%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/music-zen.jpg" width="32%">
</p>
<p align="center">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/wallpaper-default.png" width="32%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/wallpaper-glass.png" width="32%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/wallpaper-zen.png" width="32%">
</p>
<p align="center">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/osd-default.png" width="32%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/osd-glass.png" width="32%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/osd-zen.png" width="32%">
</p>
<p align="center">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/notify-default.png" width="32%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/notify-glass.png" width="32%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/notify-zen.png" width="32%">
</p>
<p align="center">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/boot-default.png" width="32%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/boot-glass.png" width="32%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/boot-zen.png" width="32%">
</p>

### Waybar

<p align="center">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/waybar-default.png" width="100%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/waybar-glass.png" width="100%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/waybar-zen.png" width="100%">
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/waybar1.png" width="100%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/waybar6.png" width="100%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/waybar4.png" width="100%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/waybar3.png" width="100%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/waybar2.png" width="100%">
  <img src="https://github.com/user-attachments/assets/31668572-b35d-4acb-8525-8cb0e5669101" width="100%">
  <img src="https://github.com/user-attachments/assets/f8c723c0-a9c9-4fa6-a3c8-bda06e81f81d" width="100%">
</p>

### Quickshell Bar

<p align="center">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/quickshellbar-default.png" width="100%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/quickshellbar-attached.png" width="100%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/quickshellbar-experimental.png" width="100%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/quickshellbar-full.png" width="100%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/quickshellbar-zen.png" width="100%">
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/quickshellbar-attached.gif" width="100%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/quickshellbar.gif" width="100%">
</p>

### Other Applications

**Neovim**

<p align="center">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/nvim-default.png" width="32%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/nvim-glass.png" width="32%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/nvim-zen.png" width="32%">
</p>
<p align="center">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/nvim1.png" width="32%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/nvim2.png" width="32%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/nvim3.png" width="32%">
</p>

**Starship**

<p align="center">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/starship-default.png" width="32%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/starship-glass.png" width="32%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/starship-zen.png" width="32%">
</p>
<p align="center">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/starship.png" width="32%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/starship1.png" width="32%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/starship2.png" width="32%">
</p>

**Pywalfox**

<p align="center">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/fox-default.png" width="32%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/fox-glass.png" width="32%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/fox-zen.png" width="32%">
</p>
<p align="center">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/fox1.png" width="20%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/fox2.png" width="20%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/fox3.png" width="20%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/fox4.png" width="20%">
</p>

**Wofi**

<p align="center">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/wofi1.png" width="20%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/wofi2.png" width="20%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/wofi3.png" width="20%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/wofi4.png" width="20%">
</p>

**Swaync**

<p align="center">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/swaync1.png" width="20%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/swaync2.png" width="20%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/swaync3.png" width="20%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/swaync4.png" width="20%">
</p>

**Wlogout**

<p align="center">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/wlogout1.png" width="20%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/wlogout2.png" width="20%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/wlogout3.png" width="20%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/wlogout4.png" width="20%">
</p>

**Hyprlock**

<p align="center">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/lock-default.png" width="32%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/lock-glass.png" width="32%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/lock-zen.png" width="32%">
</p>
<p align="center">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/lock.gif" width="75%">
</p>
<p align="center">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/lock1.PNG" width="48%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/lock2.png" width="48%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/lock3.png" width="48%">
  <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/lock4.png" width="48%">
</p>

### GIFs

<table>
  <tr>
    <td align="center" width="33%">
      <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/launcher.gif" width="100%">
    </td>
    <td align="center" width="33%">
      <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/settings.gif" width="100%">
    </td>
    <td align="center" width="33%">
      <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/music.gif" width="100%">
    </td>
  </tr>
  <tr>
    <td align="center" width="33%">
      <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/wallpaper.gif" width="100%">
    </td>
    <td align="center" width="33%">
      <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/osd.gif" width="100%">
    </td>
    <td align="center" width="33%">
      <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/notify.gif" width="100%">
    </td>
  </tr>
  <tr>
    <td align="center" width="33%">
      <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/boot.gif" width="100%">
    </td>
    <td align="center" width="33%">
      <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/profiles.gif" width="100%">
    </td>
    <td align="center" width="33%">
      <img src="https://raw.githubusercontent.com/elifouts/Dotfiles/main/images/v2/wallpaper-picker.gif" width="100%">
    </td>
  </tr>
</table>

</details>

## Keybinds

`Mod+Q` - Open Terminal

`Super` (tap) - App Launcher

`Mod+M` - Quit Hyprland

`Mod+B` - Close

`Mod+F` - Fullscreen

`Mod+V` - Popout

`Mod+L` - Lock

`Mod+Space` - Terminal Scratch Pad

`Mod+E` - Opens Thunar

`Alt+Tab` - Home Screen

`Alt+S` - Settings Panel

`Alt+W` - Wallpaper Picker

`Alt+Enter` - Music Player

`Alt+A` - Reload Bar

> [!NOTE]
> Not every keybind. Tap `Super` → **Keybinds** to see all of them, or edit `~/.config/hypr/Modern/base/shortcuts.lua`.

## Help

<details>
  <summary><picture><img src="images/badges/apps-fuzzy-or-blurry-v2.svg" alt="Apps Fuzzy or Blurry?" align="absmiddle"></picture></summary>

  Electron apps (`Spotify`, `Discord`) may need Wayland flags. Add this after the `Exec=` command in `/usr/share/applications/{app}.desktop`:

  ```
  --enable-features=UseOzonePlatform --ozone-platform=wayland --uri=%U
  ```

  This gets reset when the app updates. Know a better fix? Let me know!
</details>

<details>
  <summary><picture><img src="images/badges/cant-find-a-file-that-is-in-cache-v2.svg" alt="Cant Find a file that is in .cache?" align="absmiddle"></picture></summary>

  Files like `/home/eli/.cache/wal/colors-waybar.css` are made by `Pywal`. Replace `eli` with your username, or define the colors yourself in the `style.css`:

  ```
  @define-color background <Color>;
  @define-color color0 <Color>;
  ```
</details>

## Notes
- Cava follows `Pywal` too. The config is in `.config/cava`.
<details>
  <summary><picture><img src="images/badges/download-suggestions-v2.svg" alt="Download Suggestions" align="absmiddle"></picture></summary>

  What I install on a new machine. Do your own research before installing all of it!

```txt
git
quickshell
nvim
zip unzip
pipewire
hyprpicker
hypridle
hyprshot
pyprland
code
bottom
myfetch
yay
wl-clipboard
nerd-fonts
starship
thunar
grim
slurp
gnome-network-displays
discord
Firefox
spotify ncspot
pacman-contrib
python-pywal16
waybar
awww
blueman
bluez
networkmanager
gvfs
libnotify
pavucontrol
pipewire-pulse
nwg-look
cava
python-pywalfox
auto-cpufreq
powertop
qogir-icon-theme
fd
noto-fonts
libreoffice-fresh
materia-dark-gtk
```

  Fun to have

  ```
  asciiquarium
  pipes-rs
  clock-rs
  libcaca
  cowsay
  snake
  2048
  terminal-mines mines-tui
  genact
  no-more-secrets
  lolcat
  ```
  Cool things you don't need
  ```
  waypaper
  ranger
  howdoi
  ```
</details>
