# Theming Utilities

Scripts in this folder help with dynamic theming across window manager components (Waybar, Rofi, GTK, etc.).

- `build_theme_index.py`: Scans theme folders and builds a JSON index of available themes and their flavors.
- Future tools may include dynamic theme switchers or generators.

Dependencies:
- Python 3.12+ (required for Path.walk())
- Assumes a $HOME/themes structure as documented in the script.

