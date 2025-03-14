#!/usr/bin/env python3

"""
Combines multiple Python files from a project directory into a single file for LLM ingestion.

This script recursively scans a specified directory for Python files, applies inclusion/exclusion
filters, and outputs the combined content in either plain text or JSON format. It’s designed to
prepare Python projects for analysis or processing by large language models (LLMs). Features
include customizable file encoding, a table of contents option for text output, and support
for configuration via JSON files.

Usage:
    python combine_python_projects.py /path/to/project --output combined.txt --toc
    python combine_python_projects.py . --format json --include "app_*.py"

See --help for full options.
"""

import argparse
from pathlib import Path
import sys
import fnmatch
import json
import logging

def combine_python_files(
    project_dir: Path,
    output_file: Path,
    exclude_dirs: list[str],
    include: list[str] | None,
    exclude_files: list[str] | None,
    encoding: str,
    format: str,
    toc: bool,
) -> None:
    """
    Combines all Python files in a project directory into a single file.

    Args:
        project_dir: The root directory of the Python project.
        output_file: The path to the output file.
        exclude_dirs: List of directory names to exclude.
        include: Optional list of file patterns to include.
        exclude_files: Optional list of file patterns to exclude.
        encoding: Encoding to use for reading input files.
        format: Output format ('text' or 'json').
        toc: Whether to include a table of contents (for 'text' format).
    """
    logger = logging.getLogger(__name__)
    files: list[Path] = []
    
    # Collect all .py files, applying exclusion and inclusion filters
    for filepath in sorted(project_dir.rglob("*.py")):
        # Skip if file is in an excluded directory
        if any(excluded in filepath.parts for excluded in exclude_dirs):
            continue
        if include and not any(fnmatch.fnmatch(filepath.name, pattern) for pattern in include):
            continue
        if exclude_files and any(fnmatch.fnmatch(filepath.name, pattern) for pattern in exclude_files):
            continue
        files.append(filepath)
        
    if not files:
        logger.warning("No Python files found matching the criteria.")
        return
    
    if format == 'text':
        with output_file.open('w', encoding="utf-8") as outfile:
            if toc:
                outfile.write("# Table of Contents\n")
                for filepath in files:
                    relative_path = filepath.relative_to(project_dir)
                    outfile.write(f"# - {relative_path}\n")
                outfile.write("# ---\n")
                