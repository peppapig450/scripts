#!/usr/bin/env python
import argparse
import subprocess
import warnings
from abc import ABC, abstractmethod
from collections import Counter
from pathlib import Path
from typing import Type

try:
    import magic

    python_magic = True  # Set to true to indicate we're using magic for file types
except ModuleNotFoundError:
    warnings.warn(
        "Warning: 'python-magic' library not found. Install from package manager or use pip with a virtual environment.\n"
        "Using 'subprocess' with 'file' for file analysis."
    )
    python_magic = False  # Set python_magic to False to indicate fallback

type FileTypes = dict[Path, str]


class PackageAnalysisError(Exception):
    """Base exception class for package analysis errors."""


class DistributionDetectionError(PackageAnalysisError):
    """Exception raised for errors in detecting the distribution."""


class PackageNotInstalledError(PackageAnalysisError):
    """Exception raised when the specified package is not installed."""


class AnalyzerCreationError(PackageAnalysisError):
    """Exception raised for errors in creating an analyzer."""


class PackageContentAnalyzer(ABC):
    @abstractmethod
    def is_package_installed(self, package_name: str) -> bool:
        """
        Checks if the specified package is installed on the system.

        Args:
            package_name (str): Name of the package to check.

        Returns:
            bool: True if the package is installed, False otherwise.
        """

    @abstractmethod
    def get_file_list(self, package_name: str) -> list[str]:
        """
        Retrieves a list of files belonging to the specified package.

        Args:
            package_name (str): Name of the package to get files for.

        Returns:
            list: List of file paths within the package.
        """

    def analyze_files(self, file_list: list[str]):
        """
        Analyzes file types of files in the provided list.

        Args:
            file_list (list): List of file paths belonging to the package.

        Returns:
            FileTypes: Dictionary mapping file paths to their types.
        """
        file_types: FileTypes = {}

        for file in file_list:
            # Resolve symlinks using pathlib
            file_path = Path(file).resolve()

            if not file_path.is_file():
                continue

            if python_magic:
                with file_path.open("rb") as file:
                    file_buffer = file.read(2048)

                # Use python-magic to get the file type from libmagic
                file_type = magic.from_buffer(file_buffer)  # type: ignore
            else:
                # Use the 'file' command line tool to get the file type
                # TODO: look into operating over the whole list at once
                file_type = (
                    subprocess.check_output(["file", file])
                    .decode()
                    .split(":", 1)[1]
                    .strip()
                )

            file_types[file_path] = file_type

        return file_types

    def display_output(
        self,
        file_types: FileTypes,
        list_output: bool | None,
        summarize_output: bool | None,
    ):
        """
        Displays the results of file type analysis based on user-specified options.

        Args:
            file_types (dict[Path, str]): A dictionary mapping file paths (Path objects) to their corresponding file types (strings).
            list_output (bool, optional): If True, prints a list of files and their types. Defaults to False.
            summarize_output (bool, optional): If True, prints a summary of file types and their counts. Defaults to False.

        Returns:
            None

        This function allows for printing either a list of analyzed files with their types or a summary of the encountered
        file types and their counts based on the provided boolean flags. It avoids unnecessary processing by using separate checks for each output type.
        """
        if list_output:
            for file, file_type in file_types.items():
                print(f"File: {str(file)} - Type: {file_type}")

        if summarize_output:
            file_type_counts = Counter(file_types.values())

            # Print the summary using Counter
            print("\nSummary of file types:")
            for file_type, count in file_type_counts.most_common():
                print(f"{count} files are of type {file_type}")


class AptPackageContentAnalyzer(PackageContentAnalyzer):
    def is_package_installed(self, package_name: str) -> bool:
        """
        Checks if the specified APT package is installed on the system.

        Args:
            package_name (str): Name of the package to check.

        Returns:
            bool: True if the package is installed, False otherwise.
        """
        result = subprocess.run(
            ["dpkg-query", "-l", package_name],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=True,
        )
        return result.returncode == 0

    def get_file_list(self, package_name: str) -> list[str]:
        """
        Retrieves a list of files belonging to the specified APT package.

        Args:
            package_name (str): Name of the package to get files for.

        Returns:
            list: List of file paths within the package.

        Raises:
            PackageAnalysisError: If there is an error retrieving the package contents.
        """
        try:
            files = (
                subprocess.check_output(["dpkg-query", "-L", package_name])
                .decode()
                .splitlines()
            )
            return files
        except subprocess.CalledProcessError as e:
            raise PackageAnalysisError(
                "Something went wrong getting the content of the specified APT package."
            ) from e


class AnalyzerFactory:
    PACKAGE_ANALYZERS: dict[str, Type[PackageContentAnalyzer]] = {
        "debian": AptPackageContentAnalyzer,
    }

    @staticmethod
    def _detect_distribution() -> str:
        """
        Detects the distribution ID_LIKE from os-release files.

        Returns:
            str: The distribution ID_LIKE.

        Raises:
            DistributionDetectionError: If ID_LIKE is not found in any os-release files.
        """
        os_release_paths = [
            "/etc/os-release",
            "/usr/lib/os-release",
            "/etc/initrd-release",
            "/usr/lib/extension-release.d/extension-release.IMAGE",
        ]

        for file_path in os_release_paths:
            file_path = Path(file_path).resolve()
            if file_path.is_file():
                with file_path.open("r", encoding="utf-8") as file:
                    for line in file:
                        if line.startswith("ID_LIKE"):
                            return line.split("=")[1].strip().strip('"')
        raise DistributionDetectionError(
            "ID_LIKE not found in any of the os_release files or os_release files not there."
        )

    @classmethod
    def get_analyzer(cls) -> PackageContentAnalyzer:
        """
        Returns an appropriate PackageContentAnalyzer based on the detected distribution.

        Returns:
            PackageContentAnalyzer: An instance of the appropriate analyzer.

        Raises:
            AnalyzerCreationError: If no suitable analyzer is found for the distribution.
        """
        distribution = cls._detect_distribution()
        try:
            analyzer_class = cls.PACKAGE_ANALYZERS[distribution]
            return analyzer_class()
        except KeyError as exc:
            raise EnvironmentError(
                f"No analyzer found for distribution {distribution}'s package manager"
            ) from exc


def main():
    """
    Main function to parse arguments and perform package analysis.
    """
    parser = argparse.ArgumentParser(
        description="Analyze package contents across Linux distrubitions."
    )
    parser.add_argument(
        "-p",
        "--package",
        required=True,
        type=str,
        help="Specify the package to analyze.",
    )
    parser.add_argument(
        "-l", "--list", action="store_true", help="List each file with its type."
    )
    parser.add_argument(
        "-s",
        "--summarize",
        action="store_true",
        help="Summarize the file types with number of each type.",
    )
    parser.add_argument(
        "-b",
        "--both",
        action="store_true",
        help="Both list and summarize the file types.",
    )

    args = parser.parse_args()

    if not args.list and not args.summarize and not args.both:
        parser.print_help()
        raise ValueError(
            "Error: at least one of these options (-l, -s, -b) must be specified."
        )

    try:
        analyzer = AnalyzerFactory.get_analyzer()
    except EnvironmentError as exc:
        raise AnalyzerCreationError from exc

    if not analyzer.is_package_installed(args.package):  # type: ignore
        raise PackageNotInstalledError(
            "Package: '{args.package}' not found or not installed."
        )

    file_list = analyzer.get_file_list(args.package)
    file_types = analyzer.analyze_files(file_list)

    list_output = args.list or args.both
    summarize_output = args.summarize or args.both

    analyzer.display_output(file_types, list_output, summarize_output)


if __name__ == "__main__":
    main()
