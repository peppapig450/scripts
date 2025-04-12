#!/usr/bin/env python3
"""
Identify external dependencies in a Python project by scanning Python files and extracting import statements.

Usage:
    python find_external_imports.py <path> [--pattern <pattern>] [--output <output>]

Arguments:
    path        Directory path or glob pattern to search for Python files
    --pattern   File pattern for Python files (default: "**/*.py")
    --output    Output method: "print" or "requirements" (default: "print")
"""
from __future__ import annotations
import ast
import sys
import glob
import argparse
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from functools import lru_cache
import logging
from typing import Literal

type ModuleName = str
type OutputMethod = Literal["print", "requirements"]

logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
logger = logging.getLogger(__name__)


def extract_file_info(file_path: Path) -> tuple[set[ModuleName], set[ModuleName]]:
    """Extract imports and top-level module name from a Python file in one pass."""
    try:
        with file_path.open("r", encoding="utf-8") as file:
            content = file.read()
            tree = ast.parse(content, filename=file_path)
    except (SyntaxError, UnicodeDecodeError) as e:
        logger.warning("Skipping %s: %s", file_path, str(e))
        return set(), set()

    imports: set[ModuleName] = set()
    for node in ast.walk(tree):
        match node:
            case ast.Import(names=names):
                imports.update(alias.name.split(".")[0] for alias in names)
            case ast.ImportFrom(
                module=module, level=0
            ) if module:  # Absolute imports only
                imports.add(module.split(".")[0])

    # Derive top-level module name from file path
    rel_path = file_path.relative_to(
        file_path.parent.parent if file_path.parent.parent else Path.cwd()
    )
    module_name = rel_path.with_suffix("").as_posix().replace("/", ".")
    if module_name.endswith(".__init__"):
        module_name = module_name[:-9]
    top_level = module_name.split(".")[0]

    return imports, set(top_level)


@lru_cache()
def get_std_lib_modules() -> set[ModuleName]:
    """Retrieve standard library module names (cached)."""
    return set(sys.stdlib_module_names)


def find_external_dependencies(
    path: str, pattern: str = "**/*.py"
) -> tuple[set[ModuleName], set[ModuleName]]:
    """Find external dependencies in a given directory or file pattern."""
    path_obj = Path(path).resolve()
    external_deps: set[ModuleName] = set()
    local_modules: set[ModuleName] = set()

    if path_obj.is_dir():
        files = list(path_obj.rglob(pattern))
    else:
        files = [Path(file) for file in glob.glob(path, recursive=True)]

    if not files:
        logger.warning(
            "No Python files found matching pattern '%s' in '%s'", pattern, path
        )
        return external_deps, local_modules

    with ThreadPoolExecutor() as executor:
        results = executor.map(extract_file_info, files)

    for imports, module_names in results:
        external_deps.update(imports)
        local_modules.update(module_names)

    return external_deps, local_modules


def save_to_requirements_file(
    dependencies: set[ModuleName], file_path: Path = Path("requirements.txt")
) -> None:
    """Save external dependencies to a requirements.txt file"""
    try:
        if file_path.exists():
            logger.warning("Overwriting existing %s", file_path)
        file_path.write_text("\n".join(sorted(dependencies)) + "\n", encoding="utf-8")
        logger.info("Dependencies saved to %s", file_path)
    except IOError:
        logger.exception("Failed to write to %s", file_path)


def print_dependencies(dependencies: set[ModuleName]) -> None:
    """Print external dependencies to console."""
    if dependencies:
        print("External dependencies:")
        print("\n".join(f"- {dep}" for dep in sorted(dependencies)))
    else:
        print("No external dependencies found.")


def main() -> None:
    """Main execution function."""
    parser = argparse.ArgumentParser(
        description="Find external dependencies in Python files.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument("path", help="Directory path or glob pattern")
    parser.add_argument(
        "--pattern", default="**/*.py", help="File pattern for Python files"
    )
    parser.add_argument(
        "--output",
        type=str,
        choices=["print", "requirements"],
        default="print",
        help="Output method",
    )

    args = parser.parse_args()

    try:
        external_deps, local_modules = find_external_dependencies(
            args.path, args.pattern
        )
    except Exception as e:
        logger.error(f"Error processing files: {e}")
        sys.exit(1)

    std_modules = get_std_lib_modules()
    external_deps -= std_modules
    external_deps -= local_modules

    match args.output:
        case "print":
            print_dependencies(external_deps)
        case "requirements":
            save_to_requirements_file(external_deps)


if __name__ == "__main__":
    main()
