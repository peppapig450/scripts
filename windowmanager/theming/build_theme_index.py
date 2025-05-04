#!/usr/bin/env python3
"""
Build an index mapping available themes, applications, and flavors to absolute file
paths under a theme directory.

Usage
-----
    python build_theme_index.py [-d DIR] [-o OUTPUT] [-e EXT [EXT ...]] [-v]

Where
    DIR      Theme root directory (defaults to $HOME/themes)
    OUTPUT   Path of JSON index to create (defaults to DIR/index/themes.json)
    EXT      Allowed file extensions to index; repeatable. Defaults:
             .css .rasi .conf .yaml .yml .json

Example
-------
    $ python build_theme_index.py -v
    2025-05-04 10:00:00 INFO     Indexed 3 themes -> /home/alice/themes/index/themes.json
"""
from __future__ import annotations

import argparse
import json
import logging
import sys
from pathlib import Path
from typing import Any, Final

MIN_PY: Final = (3, 12)

if sys.version_info < MIN_PY:
    raise RuntimeError(
        f"Python {'.'.join(map(str, MIN_PY))}+ is required "
        f"(detected {sys.version.split()[0]})"
    )

# --------------------------------------------------------------------------- #
# Constants
# --------------------------------------------------------------------------- #
DEFAULT_ALLOWED_EXT: Final[set[str]] = {
    ".css",
    ".rasi",
    ".conf",
    ".yaml",
    ".yml",
    ".json",
}

IGNORE_FILES: Final[frozenset[str]] = frozenset(
    {"LICENSE", "README", "README.md", "readme.txt"}
)

# --------------------------------------------------------------------------- #
# Helpers
# --------------------------------------------------------------------------- #

def build_index(
    theme_root: Path,
    *,
    allowed_ext: set[str] = DEFAULT_ALLOWED_EXT,
) -> dict[str, Any]:
    """
    Recursively scan *theme_root* and build an index mapping:

        theme -> application -> flavor -> {"file": <abs path>, "type": <suffix>}

    Only files whose suffix is contained in *allowed_ext* are considered.

    Parameters
    ----------
    theme_root :
        Directory containing themes organised as <theme>/<application>/file.ext
    allowed_ext :
        Collection of filename suffixes to include (must start with a dot)

    Returns
    -------
    index :
        Nested mapping as described above
    """
    index: dict[str, Any] = {}

    for dirpath, _dirnames, filenames in theme_root.walk():
        rel = dirpath.relative_to(theme_root)

        # Skip the directory that contains previously generated indices
        if rel.parts and rel.parts[0] == "index":
            continue

        # Expect exactly <theme>/<application>
        if len(rel.parts) != 2:
            continue

        theme_name, app_name = rel.parts

        theme_entry = index.setdefault(
            theme_name,
            {
                "meta": {
                    "description": f"Theme {theme_name}",
                    "author": "Unknown",
                    "license": "Unknown",
                }
            },
        )
        app_entry: dict[str, Any] = theme_entry.setdefault(app_name, {})

        for fname in filenames:
            fpath = dirpath / fname
            if (
                fname in IGNORE_FILES
                or fpath.suffix.lower() not in allowed_ext
                or not fpath.is_file()
            ):
                continue

            flavor = fpath.stem
            app_entry[flavor] = {
                "file": str(fpath.resolve()),
                "type": fpath.suffix.lstrip("."),
            }

    return index


def write_index(index: dict[str, Any], outfile: Path) -> None:
    """Write *index* as formatted JSON to *outfile*."""
    outfile.parent.mkdir(parents=True, exist_ok=True)
    with outfile.open("w", encoding="utf-8") as fp:
        json.dump(index, fp, indent=2)
        fp.write("\n")  # POSIX-friendly newline at EOF


def parse_args() -> argparse.Namespace:
    """Parse command‑line arguments."""
    parser = argparse.ArgumentParser(
        description="Generate an index of available window‑manager themes."
    )
    parser.add_argument(
        "-d",
        "--dir",
        type=Path,
        default=Path.home() / "themes",
        help="Root directory that contains themes (default: %(default)s)",
    )
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        help="Where to write the JSON index "
        "(default: <dir>/index/themes.json)",
    )
    parser.add_argument(
        "-e",
        "--ext",
        dest="extensions",
        metavar="EXT",
        nargs="+",
        default=list(DEFAULT_ALLOWED_EXT),
        help="File extensions to include, e.g. -e .css .rasi "
        "(default: %(default)s)",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="count",
        default=0,
        help="Increase output verbosity (repeatable)",
    )
    return parser.parse_args()


def configure_logging(verbosity: int) -> None:
    """Configure basic stderr logging level based on *verbosity* count."""
    level = logging.WARNING  # 0 flags
    if verbosity == 1:
        level = logging.INFO
    elif verbosity >= 2:
        level = logging.DEBUG

    logging.basicConfig(
        format="%(asctime)s %(levelname)-8s %(message)s",
        level=level,
        datefmt="%Y-%m-%d %H:%M:%S",
    )


def main() -> None:
    args = parse_args()
    configure_logging(args.verbose)

    theme_root: Path = args.dir.expanduser().resolve()
    if not theme_root.is_dir():
        logging.error("Theme directory %s does not exist or is not a directory", theme_root)
        raise FileNotFoundError(f"Theme directory {theme_root} does not exist or is not a directory.")

    allowed_ext = {ext.lower() if ext.startswith(".") else f".{ext.lower()}"
                   for ext in args.extensions}

    index = build_index(theme_root, allowed_ext=allowed_ext)

    output_file = (
        args.output
        if args.output is not None
        else theme_root / "index" / "themes.json"
    ).expanduser().resolve()

    write_index(index, output_file)
    logging.info("Indexed %d theme(s) -> %s", len(index), output_file)


if __name__ == "__main__":
    main()

