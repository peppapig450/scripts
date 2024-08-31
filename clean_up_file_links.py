import argparse
import logging
import re
from pathlib import Path

logger = logging.getLogger(__name__)


def extract_links(input_file: Path, output_file: Path):
    """
    Extracts URLs from an input file, splits concatenated URLs, and writes them to an output file.

    Args:
        input_file (Path): Path to the input file containing URLs.
        output_file (Path): Path to the output file where extracted URLs will be saved.

    Raises:
        FileNotFoundError: If the input file does not exist.
        IOError: If there is an issue reading from the input file or writing to the output file.
    """
    # Regular expression pattern to match URLs
    url_pattern = re.compile(r"https?://[^\s\"\'\<\>]+")

    # Ensure the input file exists before proceeding
    if not input_file.is_file():
        raise FileNotFoundError(f"Input file not found: {str(input_file)}")

    # List to hold all extracted URLs
    concatenated_urls: set[str] = set()

    try:
        with input_file.open("r") as infile, output_file.open("w") as outfile:
            for line in infile:
                # Find all URLs in the current line
                found_urls = re.findall(url_pattern, line)
                logger.debug(f"Found URLs: {found_urls}")

                for url in found_urls:
                    # Split concatenated URLs if needed
                    separated_urls = split_concatenated_urls(url)
                    logger.debug(f"Separated URLs: {separated_urls}")

                    concatenated_urls.update(separated_urls)

            # Write each separated URL to the output file
            for separated_url in concatenated_urls:
                outfile.write(separated_url + "\n")

    except IOError as io_error:
        logger.error(f"Error reading/writing file: {io_error}")


def split_concatenated_urls(url: str) -> set[str]:
    """
    Splits concatenated URLs when multiple URLs are combined without spaces.

    Args:
        url (str): A string potentially containing concatenated URLs.

    Returns:
        list[str]: A list of individual URLs separated from the input string.
    """
    prefixes = ["https://", "http://"]

    # Start with the original URL as the initial list of URLs
    separated_urls = [url]

    # Iterate through the list of possible URL prefixes
    for prefix in prefixes:
        split_urls: list[str] = []

        for url_fragment in separated_urls:
            # Find all starting indices of the prefix in the current URL fragment
            split_indices = [
                match.start() for match in re.finditer(re.escape(prefix), url_fragment)
            ]

            # If there are multiple instances of the prefix, split the fragment into individual URLs
            if len(split_indices) > 1:
                # Use split indices to slice the URL into separate parts
                split_urls.extend(
                    [
                        url_fragment[i:j]
                        for i, j in zip(split_indices, split_indices[1:] + [None])
                    ]
                )
            else:
                split_urls.append(url_fragment)

        # Update the separated URLs list with newly split URLs
        separated_urls = split_urls

    return set(separated_urls)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Extract URLs from a text file and save them to an output file."
    )
    parser.add_argument(
        "-i", "--input", required=True, help="Path to the input file containing URLs."
    )
    parser.add_argument(
        "-o",
        "--output",
        required=True,
        help="Path to the output file to save extracted URLs.",
    )
    parser.add_argument(
        "--debug", action="store_true", help="Enable debug mode for detailed logging."
    )

    args: argparse.Namespace = parser.parse_args()

    # Configure logging level based on the debug flag
    logging.basicConfig(
        level=logging.DEBUG if args.debug else logging.INFO,
        format="%(asctime)s - %(levelname)s - %(message)s",
    )

    # Resolve the input and output file paths
    input_file = Path(args.input).resolve()
    output_file = Path(args.output).resolve()

    # Call the extract_links function with provided input and output paths
    try:
        extract_links(input_file, output_file)
    except FileNotFoundError as fnf_error:
        logger.error(f"Error: {fnf_error}")
    except Exception as e:
        logger.error(f"Unexpected error occurred: {e}")
