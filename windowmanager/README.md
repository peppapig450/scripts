# Window Manager Scripts

This directory contains scripts related to managing and enhancing window manager environments.
If it makes your desktop prettier, smarter, or slightly less embarassing, it goes here.

---

## Purpose

- Centralize scripts that interact with your Window Manager (Hyprland, sway, wayfire, bspwm, etc.).
- Include utilities for managing wallpapers, status bars, dynamic theming, and startup tasks.
- Avoid scattering WM-specific hacks across unrelated directories.

---

## Structure

Scripts are organized into subfolders by purpose or tool, for example:

- `wallpaper/` - Scripts for wallpaper randomization, theming (e.g., with [lutgen](https://github.com/ozwaldorf/lutgen-rs)), and transition effects.
- `waybar/` - Custom modules, event hooks, and tweaks for the Waybar status bar.
- `hyprland/` – Startup automation, keybind helpers, dynamic workspace managers.
  - `hypr_window_switcher.py`: Interactive window picker using `fuzzel` and Hyprland IPC.
  - `hyprland_utils/`: Internal helper module for talking to Hyprland over IPC.

- `fuzzel/` – Launchers, menu utilities, or other random popups nobody asked for.

---

## How to Use

- Scripts are standalone unless noted otherwise.
- Some scripts assume specific tools (`sww`, `lutgen`, `fuzzel`, `waybar`, etc.) are installed.
- Many scripts accept environment variables or positional arguments for customization.
    (Because hardcoding everything is for cowards.)

---

## Hyprland Scripts

### `hypr_window_switcher.py`

An interactive script to list and switch between open Hyprland windows using `fuzzel`. Supports:

- Filtering only visible, valid windows.
- Moving selected windows to the current workspace (optional flag).
- Fullscreen handling for the current workspace.
- Optional extra dispatch commands from a TOML config (`~/.config/hypr-window-switcher/extra_dispatchers.toml`).

Usage:

```bash
./hypr_window_switcher.py [--move-to-current-workspace]
```

Requirements:

- `fuzzel` (for UI)
- `tomli` (only if you're using Python < 3.11)

---

## Contribution Guidelines (for me if I forget)

- Name scripts clearly based on their purpose.
- Add a short comment header at the top of each script explaining what it does.
- If a script is tool-specific (e.g., Waybar-only), put it in a subfolder.
- Feel free to be lazy, but at least be *organized* lazy.

---
