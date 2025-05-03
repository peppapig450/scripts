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
- `rofi/` – Launchers, menu utilities, or other random popups nobody asked for.

---

## How to Use
- Scripts are standalone unless noted otherwise.
- Some scripts assume specific tools (`sww`, `lutgen`, `rofi`, `waybar`, etc.) are installed.
- Many scripts accept environment variables or positional arguments for customization.
    (Because hardcoding everything is for cowards.)

---

## Contribution Guidelines (for me if I forget)
- Name scripts clearly based on their purpose.
- Add a short comment header at the top of each script explaining what it does.
- If a script is tool-specific (e.g., Waybar-only), put it in a subfolder.
- Feel free to be lazy, but at least be *organized* lazy.

---
