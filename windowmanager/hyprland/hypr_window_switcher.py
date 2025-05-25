#!/usr/bin/env python

"""
hypr-window-switcher: Interactive window switcher for Hyprland using fuzzel.

Author: peppapig450 <peppapig450@pm.me>.
Version: 0.1.0
Dependencies:
    - HyprlandIPC (custom module)
    - fuzzel (must be installed and available in PATH)
    - tomli (for Python < 3.11)

Description:
    This script lists all open Hyprland windows via IPC, allows user selection via fuzzel,
    and optionally moves the selected window to the current workspace. Additional dispatches
    can be configured via a TOML file in XDG_CONFIG_HOME or /etc.

    This Python version is based on the original Nu shell implementation by kai-tub:
    https://github.com/kai-tub/hypr-window-switcher

    Many thanks to kai-tub for the original idea and logic, particularly around fullscreen
    handling and workspace behaviors.

Usage:
    python window_switcher.py [--move-to-current-workspace]
"""

from __future__ import annotations

import argparse
import logging
import os
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

from hyprland_utils import HyprlandIPC, HyprlandIPCError

try:
    if sys.version_info >= (3, 11):
        import tomllib as toml
    else:
        import tomli as toml
except ImportError:
    raise ImportError(
        "No TOML parser found. Install `tomli` for Python < 3.11: `pip install tomli`"
    )

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("hypr-window-switcher")


def get_extra_dispatches() -> list[str]:
    """
    Loads additional IPC dispatch commands from a TOML config file if available.

    Returns:
        list[str]: A list of extra dispatch commands as strings.
    """
    config_home = os.getenv("XDG_CONFIG_HOME", "~/.config")
    cfg_rel_path = Path("hypr-window-switcher") / "extra_dispatchers.toml"
    user_cfg = Path(config_home).expanduser() / cfg_rel_path
    sys_cfg = Path("/etc") / cfg_rel_path

    # Check for user config, fallback to system config
    cfg = user_cfg if user_cfg.is_file() else sys_cfg
    if not cfg.is_file() or cfg.stat().st_size == 0:
        return []

    try:
        with cfg.open("rb") as config_file:
            data = toml.load(config_file)
        dispatches = data.get("dispatches", [])
        if isinstance(dispatches, list):
            logger.debug("Loaded extra dispatches: %s", dispatches)
            # Ensure commands are non-empty strings
            return [
                str(cmd) for cmd in dispatches if isinstance(cmd, str) and cmd.strip()
            ]
    except (OSError, toml.TOMLDecodeError):
        logger.exception("Error loading extra dispatches from %s", cfg)
    return []


def get_windows(ipc: HyprlandIPC) -> list[dict[str, Any]]:
    """
    Retrieves a sorted list of currently open and visible Hyprland windows.

    Args:
        ipc (HyprlandIPC): An instance of the HyprlandIPC interface.

    Returns:
        list[dict[str, Any]]: List of window info dictionaries.
    """
    try:
        windows = ipc.get_clients()
    except HyprlandIPCError:
        logger.exception("Failed to get window list")
        return []

    # Filter windows: must not be hidden and must have a valid monitor
    windows = [w for w in windows if not w["hidden"] and w["monitor"] != -1]
    # Sort by focus history, ensuring recent windows come up last
    windows.sort(key=lambda w: w.get("focusHistoryID", 0))
    # Cycle list for a more natural index in fuzzel
    if windows:
        windows = windows[1:] + windows[:1]
    return windows


def pick_window(windows: list[dict[str, Any]]) -> dict[str, Any] | None:
    """
    Presents a window picker using fuzzel and returns the user's selected window.

    Args:
        windows (list[dict[str, Any]]): List of window information dicts.

    Returns:
        dict[str, Any] | None: The window dict selected by the user, or None if cancelled.
    """
    # Format each window entry for fuzzel, include workspace, title, and app class
    entries = [
        f"[{w['workspace']['name']}] {w['title']} | {w['class']}\u0000icon\u001f{w['class']}"
        for w in windows
    ]

    result = subprocess.run(
        ["fuzzel", "--dmenu", "--index"],
        input="\n".join(entries),
        text=True,
        capture_output=True,
    )

    if not result.stdout.strip():
        # User pressed none or canceled
        return None
    try:
        idx = int(result.stdout.strip())
        return windows[idx]
    except (ValueError, IndexError):
        return None


def minify_fullscreen_cmds(
    windows: list[dict[str, Any]], ws_id: int, exclude_addr: str
) -> list[str]:
    """
    Generates commands to remove fullscreen state from all windows
    in the given workspace, except for the one to be focused.

    Args:
        windows (list[dict[str, Any]]): List of window dicts.
        ws_id (int): Target workspace ID.
        exclude_addr (str): Address of the window to exclude.

    Returns:
        list[str]: List of IPC commands as strings.
    """
    return [
        f"focuswindow address:{w['address']}; fullscreen 0"
        for w in windows
        if (
            w.get("workspace", {}).get("id") == ws_id
            and w.get("fullscreen")
            and w.get("address") != exclude_addr
        )
    ]


def _get_int_or_raise(d: dict[str, Any], key: str) -> int:
    """
    Helper function to get an integer value from a dictionary by key.

    Args:
        d (dict[str, Any]): The dictionary to look up.
        key (str): The key to retrieve.

    Returns:
        int: The integer value.

    Raises:
        HyprlandIPCError: If the key does not exist or is not an int.
    """
    val = d.get(key)
    if not isinstance(val, int):
        raise HyprlandIPCError(
            f"Expected int for key '{key}', got {type(val).__name__}"
        )
    return val


def main(move_to_current_workspace: bool = False):
    """
    Main entry point of the script. Handles window picking, moving, and focusing logic.

    Args:
        move_to_current_workspace (bool): Whether to move the selected window to the
                                          currently active workspace.

    Returns:
        int: Exit status code (0 for success, 1 for error).
    """
    # Ensure fuzzel is installed
    if shutil.which("fuzzel") is None:
        logger.error("Required dependency 'fuzzel' not found in PATH. Please install it.")
        return 1

    try:
        ipc = HyprlandIPC.from_env()
    except HyprlandIPCError as e:
        logger.exception(e)
        return 1

    if not (windows := get_windows(ipc)):
        logger.info("No windows found... Exiting.")
        return 0

    # Load extra dispatchers from TOML file
    extra_dispatches = get_extra_dispatches()

    try:
        # Get the currently focused window and workspace
        active_window = ipc.get_active_window()
        # NOTE: for now use helper func for type narrowing, in the future
        # Pydantic could be used in the HyprlandIPC class.
        active_address = active_window.get("address")
        active_ws_id = _get_int_or_raise(ipc.get_active_workspace(), "id")

    except HyprlandIPCError:
        logger.exception("Failed to get active window/workspace")
        return 1

    try:
        # Show picker and get selected window
        if not (selected_window := pick_window(windows)):
            logger.info("Nothing selected; quitting.")
            return 0
        logger.info("Selected window: %s (%s)", selected_window['title'], selected_window['class'])

        selected_address = selected_window.get("address")
        if not isinstance(selected_address, str):
            raise HyprlandIPCError("Selected window is missing a valid address")

        # Prevent re-focusing any already focused window
        if active_address and selected_address == active_address:
            raise HyprlandIPCError("Already focused... Exiting.")

        # Determine target workspace for focusing/moving
        if move_to_current_workspace:
            target_ws_id = active_ws_id
        else:
            ws = selected_window.get("workspace")
            if not isinstance(ws, dict):
                raise HyprlandIPCError("Selected window workspace is not a dict")
            target_ws_id = _get_int_or_raise(ws, "id")

    except HyprlandIPCError:
        logger.exception("Error resolving selected window or target workspace")
        return 1

    minify_cmds = minify_fullscreen_cmds(windows, target_ws_id, selected_address)

    ipc_cmds = minify_cmds
    if move_to_current_workspace:
        ipc_cmds.append(f"movetoworkspace {active_ws_id}, address:{selected_address}")

    ipc_cmds.append(f"focuswindow address:{selected_address}")

    if extra_dispatches:
        ipc_cmds.extend(extra_dispatches)

    try:
        ipc.batch(ipc_cmds)
    except HyprlandIPCError:
        logger.exception("IPC command failed")
        return 1


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Interactive window switcher for Hyprland using fuzzel.")
    parser.add_argument(
        "--move-to-current-workspace",
        action="store_true",
        help="Move selected window to current workspace",
    )
    args = parser.parse_args()
    sys.exit((main(args.move_to_current_workspace)))
