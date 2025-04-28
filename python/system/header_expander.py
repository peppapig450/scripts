#!/usr/bin/env python

import argparse
import logging
from pathlib import Path
import re

def build_header_map(root: Path) -> dict[str, Path]:
    """
    Scan the directory tree for .h files and build a map from filename to full Path.
    """
    header_map: dict[str, Path] = {}
    for path in root.rglob('*.h'):
        header_map.setdefault(path.name, path)
    return header_map

INCLUDE_REGEX = re.compile(r'^\s*#include\s+"([^"]+)"')


def expand(
    file_path: Path,
    header_map: dict[str, Path],
    seen: Set[str] = None,
) -> None:
    """
    Recursively expand #include "..." directives by inlining header contents.

    Prints file content to stdout, with markers around expanded headers.
    """
    if seen is None:
        seen = set()

    try:
        for line in file_path.read_text(encoding='utf-8').splitlines(keepends=True):
            match = INCLUDE_REGEX.match(line)
            if match:
                include_name = match.group(1)
                if include_name not in seen and include_name in header_map:
                    include_path = header_map[include_name]
                    seen.add(include_name)
                    print(f"\n/* Begin include: {include_name} ({include_path}) */\n")
                    expand(include_path, header_map, seen)
                    print(f"\n/* End include: {include_name} */\n")
                else:
                    logging.warning(
                        "%s skipped: %s",
                        include_name,
                        "already included" if include_name in seen else "not found",
                    )
            else:
                print(line, end='')
    except FileNotFoundError:
        logging.error("File not found: %s", file_path)
    except Exception as e:
        logging.error("Error processing %s: %s", file_path, e)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Expand C/C++ #include \"...\" directives by inlining header files."
    )
    parser.add_argument(
        'source',
        type=Path,
        help="Path to the source file to process",
    )
    parser.add_argument(
        '--root',
        type=Path,
        default=Path('.'),
        help="Root directory to search for headers (default: current directory)",
    )
    parser.add_argument(
        '--verbose',
        '-v',
        action='store_true',
        help="Enable debug logging",
    )
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format='%(levelname)s: %(message)s',
    )

    header_map = build_header_map(args.root)
    logging.info(
        "Found %d headers under %s",
        len(header_map),
        args.root,
    )

    expand(args.source, header_map)


if __name__ == '__main__':
    main()

