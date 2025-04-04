#!/usr/bin/env python
"""
Script to identify Python files based on different methods.

Usage:
    python find_python_files.py [options] [paths]

Options:
    -h, --help             Show this help message and exit.
    -p, --pipe             Read paths from pipe.
    -d, --directory        Search directory for Python files. Does not print out invalid Python files.

Arguments:
    paths                  List of files or directories to check.
"""
import argparse
import ast
import importlib.util
import os
import sys
from collections import namedtuple

IdentificationResult = namedtuple(
    "IdentificationResult", ["is_python", "determined_by"]
)


def identify_python_file_magic(filename):
    # Try to import libmagic dynamically
    try:
        spec = importlib.util.find_spec("magic")
        if spec is not None:
            magic = importlib.util.module_from_spec(spec)
            if spec.loader is not None:
                spec.loader.exec_module(magic)
                # Use magic to determine file type
                file_type = magic.Magic(mime=True).from_file(filename)
                # Check if the file type indicates a python script
                valid_types = ("text/x-script.python", "application/x-python-bytecode")
                if file_type in valid_types:
                    return IdentificationResult(True, "with libmagic")
    except ImportError:
        pass
    return IdentificationResult(False, None)


def identify_file_ext_or_shebang(filename):
    if filename.endswith(".py") or filename.endswith(".pyc"):
        return IdentificationResult(True, "with file extension")

    # Check if the file has a shebang indicating it's a python script
    with open(filename, "rb") as file:
        first_line = file.readline().decode("utf-8").strip()
        if first_line.startswith("#!") and "python" in first_line.lower():
            return IdentificationResult(True, "with shebang")
    return IdentificationResult(False, None)


def identify_with_ast(filename):
    # Try to parse the file with ast
    try:
        with open(filename, "r", encoding="utf-8") as file:
            source = file.read(4096)
            ast.parse(source)
            return IdentificationResult(True, "with ast")
    except (SyntaxError, FileNotFoundError):
        return IdentificationResult(False, None)


def is_valid_python_file(filename):
    # Try all 3 steps
    for method in (
        identify_python_file_magic,
        identify_file_ext_or_shebang,
        identify_with_ast,
    ):
        result = method(filename)

        if result.is_python:
            return result
    return IdentificationResult(False, "Not a Python file")


def handle_path(paths, is_valid_python_file):
    for path in paths:
        if os.path.isfile(path):
            result = is_valid_python_file(path)
            if result.is_python:
                print(f"{path} is a Python file, determined ({result.determined_by}).")
            else:
                print(f"{path} is not a valid Python file.")
        else:
            print(f"{path} is not a valid file.")


def handle_directory(paths, is_valid_python_file):
    for path in paths:
        if os.path.isdir(path):
            for root, _, files in os.walk(path):
                for file in files:
                    full_path = os.path.join(root, file)
                    result = is_valid_python_file(full_path)
                    if result.is_python:
                        print(
                            f"{os.path.join(root, file)} is a Python file determined ({result.determined_by})."
                        )
        else:
            print(f"{path} is not a valid directory.")


def main():
    parser = argparse.ArgumentParser(description="Identify Python files.")
    parser.add_argument(
        "paths",
        nargs="*",
        help="List of files or directores to check. (Does print out invalid Python files).",
    )
    parser.add_argument(
        "-p", "--pipe", action="store_true", help="Read paths from pipe."
    )
    parser.add_argument(
        "-d",
        "--directory",
        action="store_true",
        help="Search directory for python files. (Does not print out invalid Python files).",
    )

    args = parser.parse_args()

    if args.pipe:
        # Read paths from pipe
        paths = [line.strip() for line in sys.stdin.readlines()]
    elif not args.paths:
        # If no paths are provided, use the first argument as the input file
        paths = [sys.argv[1]]
    else:
        paths = [args.paths]

    handlers = {
        args.pipe: lambda: handle_path(paths, is_valid_python_file),
        not args.pipe
        and len(paths) == 1: lambda: handle_path(paths[0], is_valid_python_file),
        args.directory: lambda: handle_directory(paths, is_valid_python_file),
    }

    for condition, handler in handlers.items():
        if condition:
            handler()
            break


if __name__ == "__main__":
    main()
