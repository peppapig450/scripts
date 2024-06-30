#!/usr/bin/env python
from abc import ABC, abstractmethod
import warnings
import subprocess
import argparse

try:
    import magic
except ModuleNotFoundError:
    warnings.warn("Warning: 'python-magic' library not found. Install from package manager or use pip with a virtual environment.\n"
                  "Using 'subprocess' with 'file' for file analysis.")
    python_magic = None # set python_magic to None to indicate fallback


class PackageContentAnalyzer(ABC):
    @abstractmethod

