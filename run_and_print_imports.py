import types
import sys
import importlib.util
import os


def get_module_path(module_file):
    """
    returns the path of a module file
    """
    return os.path.abspath(module_file) if module_file else "Built-in module"


def get_module_paths(script_path):
    """
    Takes a path to a Python script and returns a list of all the imported module paths
    """
    spec = importlib.util.spec_from_file_location("module", script_path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)

    imported_paths = []
    for name, imported_module in module.__dict__.items():
        if isinstance(imported_module, types.ModuleType) and hasattr(
            imported_module, "__file__"
        ):
            imported_paths.append((name, get_module_path(imported_module.__file__)))

    # Add the scripts own path
    imported_paths.append(("__main__", get_module_path(script_path)))

    return imported_paths


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python run_and_print_imports.py <path/to/your/script")
        sys.exit(1)
    script_path = sys.argv[1]

    imported_paths = get_module_paths(script_path)
    print("Imported module paths:")
    for name, path in imported_paths:
        print(f"Module Name: {name}, Path: {path}")
