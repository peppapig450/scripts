#!/usr/bin/env python

import os
import sys
import modulefinder
import importlib.util
from collections import ChainMap
from typing import List, Dict


def find_import_paths_recursively(module_name: str, chain: ChainMap) -> None:
    """Recursively find the paths of modules and their dependencies."""
    if module_name in chain:
        return

    try:
        spec = importlib.util.find_spec(module_name)
        if spec and spec.origin:
            module_path = spec.origin
            finder = modulefinder.ModuleFinder()
            finder.run_script(module_path)

            dependencies = {}
            for name, module in finder.module.items():
                if module.__file__:
                    dependencies[name] = module.__file__
                    find_import_paths_recursively(
                        name, chain.new_child({name: dependencies[name]})
                    )

            chain.maps[0][module_name] = {
                "path": module_path,
                "dependencies": dependencies,
            }
    except ModuleNotFoundError:
        chain.maps[0][module_name] = {"path": None, "dependencies": {}}


def find_import_paths_using_modulefinder(file_path: str) -> ChainMap:
    """Find all the paths of modules imported in a Python file using modulefinder."""
    finder = modulefinder.ModuleFinder()
    finder.run_script(file_path)

    chain = ChainMap()
    for name, module in finder.modules.items():
        if module.__file__:
            chain.maps.append({name: {"path": module.__file__, "dependencies": {}}})
            find_import_paths_recursively(name, chain)

    return chain


def main(input_value: str):
    if os.path.isfile(input_value):
        # Input is a file
        import_paths = find_import_paths_using_modulefinder(input_value)
    else:
        print("Invalid input. Please provide a valid Python file.")
        sys.exit(1)

    print("Imported modules and their paths and dependencies:")
    for module, info in import_paths.items():
        print(f"{module}:")
        print(f"  Path: {info['path']}")
        print("  Dependencies:")
        for dep, dep_path in info["dependencies"].items():
            print(f"    {dep}: {dep_path}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python find_imports.py <path_to_python_file>")
        sys.exit(1)

    input_value = sys.argv[1]
    main(input_value)
