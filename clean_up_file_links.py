import argparse
import fileinput
import logging
import re
from pathlib import Path


def clean_links(input_files: list[str], output_file: str | None = None) -> None:
    """Cleans text files by removing all non-link content and leaving only links.

    Args:
        input_files (List[str]): A list of paths to the input files containing links and other text.
        output_file (Optional[str]): Optional. Path to the output file to save cleaned links.
                                     If not provided, files are modified in place.

    Raises:

        ValueError: If multiple input files are provided with a single output file.
        FileNotFoundError: If any of the input files do not exist.
    """

    # Configure logging
    logging.basicConfig(
        level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s"
    )

    if output_file and len(input_files) > 1:
        raise ValueError(
            "Cannot specify an output file when processing multiple input files."
        )

    # Compile the regular expression for finding URLs
    url_pattern: re.Pattern[str] = re.compile(
        r"http[s]?://(?:[a-zA-Z]|[0-9]|[$-_@.&+]|[!*\(\),]|(?:%[0-9a-fA-F][0-9a-fA-F]))+"
    )

    output_path: Path | None = Path(output_file).resolve() if output_file else None

    for input_file in input_files:
        input_path: Path = Path(input_file).resolve()

        if not input_path.is_file():
            raise FileNotFoundError(f"File not found: {input_path}")

        try:
            with fileinput.input(
                input_path, inplace=(output_path is None), backup=".bak"
            ) as file:
                # Open output file if specified
                out = output_path.open("w") if output_path else None
                for line in file:
                    try:
                        links: set[str] = set(url_pattern.findall(line))
                        if links:
                            output: str = "\n".join(links) + "\n"
                            if out:
                                out.write(output)
                            else:
                                print(output, end="")
                    except re.error as regex_error:
                        logging.error(
                            f"Regex error while processing line in {input_file}: {regex_error}"
                        )
                    except (IOError, OSError) as io_error:
                        logging.error(
                            f"I/O error while writing to {output_file if output_file else input_file}: {io_error}"
                        )
            if out:
                out.close()
            logging.info(f"Processing complete for {input_file}")
        except (FileNotFoundError, IOError, OSError) as file_error:
            logging.error(f"Error processing file {input_file}: {file_error}")
        except Exception as e:
            logging.error(f"Unexpected error while processing file {input_file}: {e}")


if __name__ == "__main__":
    parser: argparse.ArgumentParser = argparse.ArgumentParser(
        description="Clean text files by removing all non-link content."
    )
    parser.add_argument(
        "input_files", nargs="+", help="Path to one or more input files"
    )
    parser.add_argument("-o", "--output", help="Optional path to output file")
    args: argparse.Namespace = parser.parse_args()

    try:
        clean_links(args.input_files, args.output)
    except ValueError as val_error:
        logging.error(f"Value error: {val_error}")
    except FileNotFoundError as fnf_error:
        logging.error(f"File not found: {fnf_error}")
    except Exception as e:
        logging.error(f"Unexpected error: {e}")
