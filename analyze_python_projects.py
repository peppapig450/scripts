import argparse
import ast
from pathlib import Path
from pprint import pprint


class FunctionCallAnalyzer(ast.NodeVisitor):
    def __init__(self):
        self.calls = []

    def visit_Call(self, node):
        if isinstance(node.func, ast.Name):
            self.calls.append(node.func.id)
        elif isinstance(node.func, ast.Attribute):
            self.calls.append(node.func.attr)
        self.generic_visit(node)


class FunctionDefAnalyzer(ast.NodeVisitor):
    def __init__(self):
        self.functions = {}

    def visit_FunctionDef(self, node: ast.FunctionDef):
        func_name = node.name
        call_analyzer = FunctionCallAnalyzer()
        call_analyzer.visit(node)
        self.functions[func_name] = call_analyzer.calls
        self.generic_visit(node)


class MethodCallAnalyzer(FunctionCallAnalyzer):
    pass


class ClassMethodAnalyzer(ast.NodeVisitor):
    def __init__(self):
        self.methods = {}

    def visit_FunctionDef(self, node: ast.FunctionDef):
        method_name = node.name
        call_analyzer = MethodCallAnalyzer()
        call_analyzer.visit(node)
        self.methods[method_name] = call_analyzer.calls
        self.generic_visit(node)


class ClassDefAnalyzer(ast.NodeVisitor):
    def __init__(self):
        self.classes = {}

    def visit_ClassDef(self, node):
        class_name = node.name
        method_analyzer = ClassMethodAnalyzer()
        method_analyzer.visit(node)
        self.classes[class_name] = method_analyzer.methods
        self.generic_visit(node)


def analyze_file(file_path: Path) -> tuple[dict, dict]:
    with file_path.open("r") as file:
        file_content = file.read()

    tree = ast.parse(file_content)

    function_analyzer = FunctionDefAnalyzer()
    function_analyzer.visit(tree)

    class_analyzer = ClassDefAnalyzer()
    class_analyzer.visit(tree)

    return function_analyzer.functions, class_analyzer.classes


def analyze_project(directory: Path) -> dict:
    py_files = directory.glob("**/*.py")
    project_summary = {}

    for py_file in py_files:
        functions, classes = analyze_file(py_file)
        project_summary[py_file.is_relative_to(directory)] = {
            "functions": functions,
            "classes": classes,
        }

    return project_summary


def print_summary(summary: dict):
    for file, content in summary.items():
        print(f"\nFile: {file}")

        functions = content.get("functions", None)
        if functions:
            print(" Functions:")
            pprint(functions, indent=4)

        classes = content.get("classes", None)
        if classes:
            print(" Classes:")
            for cls_name, methods in classes.items():
                print(f" Class '{cls_name}':")
                pprint(methods, indent=4)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Analyze Python project structure")
    parser.add_argument(
        "directory",
        nargs="?",
        type=Path,
        default=Path.cwd(),
        help="Path to the Python project directory (defaults to current directory)",
    )

    args = parser.parse_args()

    summary = analyze_project(args.directory)

    print_summary(summary)
