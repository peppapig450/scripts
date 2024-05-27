import os
import ast
import glob
import argparse
import importlib.util
import sys
import pkgutil
import subprocess


def extract_imports_from_file(file_path):
    with open(file_path, "r") as file:
        tree = ast.parse(file.read(), filename=file_path)

    imports = set()
    for node in tree.body:
        if isinstance(node, ast.Import):
            for alias in node.names:
                imports.add(alias.name)
        elif isinstance(node, ast.ImportFrom):
            if node.module:
                imports.add(node.module)
    return imports


def find_external_dependencies(path, file_pattern="*.py"):
    if os.path.isdir(path):
        return find_external_dependencies_in_directory(path)
    else:
        return find_external_dependencies_matching_glob(path)


def find_external_dependencies_in_directory(directory):
    external_dependencies = set()
    for root, _, files in os.walk(directory):
        for file_name in files:
            if file_name.endswith(".py"):
                file_path = os.path.join(root, file_name)
                imports = extract_imports_from_file(file_path)
                external_dependencies.update(imports)
    return external_dependencies


def find_external_dependencies_matching_glob(pattern):
    external_dependencies = set()
    files = glob.glob(pattern)
    for file_path in files:
        imports = extract_imports_from_file(file_path)
        external_dependencies.update(imports)
    return external_dependencies


def resolve_import_name(import_name):
    try:
        module = importlib.import_module(import_name)
        return module.__name__
    except ImportError:
        return import_name  # Return the original name if the module is not found


def get_std_lib_modules():
    std_lib_modules = set(sys.builtin_module_names)
    std_lib_modules.update(
        module.name for module in pkgutil.iter_modules() if module.module_finder is None
    )
    # Ensure all submodules are captured
    std_lib_modules.update({name for _, name, _ in pkgutil.iter_modules()})
    return std_lib_modules


def get_installed_packages():
    installed_packages = subprocess.run(
        [sys.executable, "-m", "pip", "freeze"], stdout=subprocess.PIPE
    )
    packages = set(
        line.decode().split("==")[0] for line in installed_packages.stdout.splitlines()
    )
    return packages


def is_local_module(module_name, project_root):
    module_path = module_name.replace(".", os.sep) + ".py"
    for root, _, files in os.walk(project_root):
        if module_path in [
            os.path.relpath(os.path.join(root, file), start=project_root)
            for file in files
        ]:
            return True
    return False


def save_to_requirements_file(external_dependencies, file_path="requirements.txt"):
    with open(file_path, "w") as f:
        for module_name in external_dependencies:
            f.write(module_name + "\n")


def print_dependencies(external_dependencies):
    if external_dependencies:
        print("External dependencies:")
        for module_name in external_dependencies:
            print(f"- {module_name}")
    else:
        print("No external dependencies found.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Find external dependencies in files within a directory."
    )
    parser.add_argument(
        "path", metavar="path", type=str, help="Directory path or glob pattern"
    )
    parser.add_argument(
        "--pattern",
        metavar="pattern",
        type=str,
        default="*.py",
        help='File pattern (default is "*.py")',
    )
    parser.add_argument(
        "--output",
        metavar="output",
        type=str,
        default="print",
        choices=["print", "requirements"],
        help="Output method (print or requirements.txt)",
    )
    args = parser.parse_args()

    path = args.path
    pattern = args.pattern
    output = args.output

    external_dependencies = find_external_dependencies(path, pattern)

    # Use map to resolve import names to actual modules
    resolved_dependencies = set(map(resolve_import_name, external_dependencies))

    # Remove None values resulting from failed import attempts
    resolved_dependencies = {
        module_name for module_name in resolved_dependencies if module_name
    }

    std_lib_modules = get_std_lib_modules()
    installed_packages = get_installed_packages()

    # Determine non-standard library dependencies
    non_std_lib_dependencies = resolved_dependencies - std_lib_modules

    # Filter out local project modules
    external_dependencies = {
        module_name
        for module_name in non_std_lib_dependencies
        if not is_local_module(module_name, path)
    }

    # Filter out only external packages installed via pip
    external_dependencies = external_dependencies - installed_packages

    if output == "print":
        print_dependencies(external_dependencies)
    elif output == "requirements":
        if external_dependencies:
            save_to_requirements_file(external_dependencies)
            print("External dependencies saved to requirements.txt.")
        else:
            print("No external dependencies found.")
