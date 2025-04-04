#!/usr/bin/env python3

#TODO: maybe expand to allow other settings or integrate the installer scripts in module fashion
import re
from pathlib import Path
from dataclasses import dataclass
from fileinput import input as fileinput
from collections import defaultdict
from pprint import pprint

@dataclass
class ShellAlias:
    """Dataclass to represent a shell alias."""
    name: str
    value: str

@dataclass
class ShellFunction:
    """Dataclass to represent a shell function."""
    name: str
    body: str

def find_func_and_alias_files() -> set[str]:
    """Gets filenames from the funcs-and-aliases directory and its subdirectories."""
    filenames = set()

    parent_dir = Path(__file__).parent.parent
    funcs_and_aliases_dir = parent_dir / "funcs-and-aliases"

    if funcs_and_aliases_dir.exists():
        for root, _, files in funcs_and_aliases_dir.walk():
            for filename in files:
                filepath = root / filename
                filenames.add(str(filepath.resolve()))
        return filenames
    raise NotADirectoryError("funcs-and-aliases directory not found.")


#TODO: first part captures the name properly, body capture needs work
def capture_shell_functions(file_content: str) -> dict[str, ShellFunction]:
    function_pattern = re.compile(
        r"""
        ^\s*                        # Start of the line with optional leading whitespace
        (?:                         # Non-capturing group for the function definition
            (\w+)\s*\(\s*\)\s*      # Function name with '()'
            |                       # OR
            function\s+(\w+)\s*     # 'function' keyword followed by function name
        )
        \{                          # Opening brace of function body
        (                           # Start of the capturing group for the body
            [^{}]*                  # Match anything except braces
            (?:                     # Non-capturing group
                \{[^{}]*\}          # Match braces with non-brace content inside
                [^{}]*              # Match anything except braces
            )*                      # Zero or more of the non-capturing group
        )                           # End of the capturing group for the body
        \}                          # Closing brace of the function body
        """,
        re.VERBOSE | re.MULTILINE | re.DOTALL
    )

    # Dictionary to store functions and their bodies
    functions = {}

    # Find all matches in the file content
    for match in re.finditer(function_pattern, file_content):
        function_name = match.group(1) or match.group(2)
        function_body = match.group(3)
        functions[function_name] = ShellFunction(name=function_name, body=function_body.strip())

    return functions

def capture_shell_aliases(file_content: str) -> dict[str, ShellAlias]:
    alias_pattern = re.compile(
        r"""
        ^\s*                        # Start of the line with optional leading whitespace
        alias\s+                    # 'alias' keyword
        (\w+)=['"]?                 # Alias keyword followed by '=' and optional opening quote
        (['"\n]+)                   # Alias value (anything except quotes and newline)
        ['"]?                       # Optional closing quote
        """,
        re.VERBOSE | re.MULTILINE
    )

    # Dictionary to store aliases and their values
    aliases = {}

    # Find all matches in the file content
    for match in re.finditer(alias_pattern, file_content):
        alias_name = match.group(1)
        alias_value = match.group(2).strip()
        aliases[alias_name] = ShellAlias(name=alias_name, value=alias_value)

    return aliases

def process_files_and_gather(file_list: set[str]):
    all_functions: defaultdict[str, dict[str, ShellFunction]] = defaultdict(dict)
    all_aliases: defaultdict[str, dict[str, ShellAlias]] = defaultdict(dict)

    with fileinput(files=file_list, encoding="utf-8") as f_input:
        current_file = None
        file_content = ""

        for line in f_input:
            if f_input.isfirstline():
                if current_file is not None:
                    #TODO: create function for this
                    functions = capture_shell_functions(file_content)
                    aliases = capture_shell_aliases(file_content)
                    all_functions[current_file].update(functions)
                    all_aliases[current_file].update(aliases)
                current_file = f_input.filename()
                file_content = ""

            file_content += line

            # Process the last file's content
            if current_file is not None:
                functions = capture_shell_functions(file_content)
                aliases = capture_shell_aliases(file_content)
                all_functions[current_file].update(functions)
                all_aliases[current_file].update(aliases)

    return all_functions, all_aliases

if __name__ == "__main__":
    file_list = find_func_and_alias_files()

    functions, aliases = process_files_and_gather(file_list)

    print("Captured Functions:")
    for filename, funcs in functions.items():
        print(f"File: {filename}")
        for name, body in funcs.items():
            print(f"    Function Name: {name}")
            print(f"    Function Body:\n{body.body}\n")
    pprint(functions)

    print("Captured Aliases:")
    for filename, als in aliases.items():
        print(f"File: {filename}")
        for name, obj in als.items():
            print(f"  Alias Name: {obj.name}")
            print(f"  Alias Value: {obj.value}\n")

    pprint(aliases)
