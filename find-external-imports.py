import os
import ast
import glob
import argparse
import importlib.util
import sys
import pkgutil


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


def extract_defined_entities_from_file(file_path):
    with open(file_path, "r") as file:
        tree = ast.parse(file.read(), filename=file_path)

    defined_entities = set()
    for node in tree.body:
        if isinstance(node, ast.ClassDef):
            defined_entities.add(node.name)
        elif isinstance(node, ast.FunctionDef):
            defined_entities.add(node.name)
    return defined_entities


def find_external_dependencies(path, file_pattern="*.py"):
    if os.path.isdir(path):
        return find_external_dependencies_in_directory(path)
    else:
        return find_external_dependencies_matching_glob(path)


def find_external_dependencies_in_directory(directory):
    external_dependencies = set()
    local_definitions = set()
    for root, _, files in os.walk(directory):
        for file_name in files:
            if file_name.endswith(".py"):
                file_path = os.path.join(root, file_name)
                imports = extract_imports_from_file(file_path)
                definitions = extract_defined_entities_from_file(file_path)
                external_dependencies.update(imports)
                local_definitions.update(definitions)
    return external_dependencies, local_definitions


def find_external_dependencies_matching_glob(pattern):
    external_dependencies = set()
    local_definitions = set()
    files = glob.glob(pattern)
    for file_path in files:
        imports = extract_imports_from_file(file_path)
        definitions = extract_defined_entities_from_file(file_path)
        external_dependencies.update(imports)
        local_definitions.update(definitions)
    return external_dependencies, local_definitions


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


def is_local_module(module_name, project_root, local_definitions):
    if module_name in local_definitions:
        return True

    module_path = module_name.replace(".", os.sep)
    module_file = module_path + ".py"
    module_dir = os.path.join(module_path, "__init__.py")
    for root, _, files in os.walk(project_root):
        rel_files = [
            os.path.relpath(os.path.join(root, file), start=project_root)
            for file in files
        ]
        if module_file in rel_files or module_dir in rel_files:
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

    external_dependencies, local_definitions = find_external_dependencies(path, pattern)

    # Use map to resolve import names to actual modules
    resolved_dependencies = set(map(resolve_import_name, external_dependencies))

    # Remove None values resulting from failed import attempts
    resolved_dependencies = {
        module_name for module_name in resolved_dependencies if module_name
    }

    std_lib_modules = get_std_lib_modules()

    # Determine non-standard library dependencies
    non_std_lib_dependencies = resolved_dependencies - std_lib_modules

    external_dependencies = {
        module_name
        for module_name in non_std_lib_dependencies
        if not is_local_module(module_name, path, local_definitions)
    }

    # Filter out only external packages installed via pip

    if output == "print":
        print_dependencies(external_dependencies)
    elif output == "requirements":
        if external_dependencies:
            save_to_requirements_file(external_dependencies)
            print("External dependencies saved to requirements.txt.")
        else:
            print("No external dependencies found.")
