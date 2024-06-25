import ast
from pathlib import path

class FunctionCallAnalyzer(ast.NodeVisitor):
    def __init__(self):
        self.calls = []

