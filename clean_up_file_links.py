import argparse
import fileinput
import logging
from pathlib import Path
import re
from pprint import pprint

regex_patterns = {
    "url_pattern": re.compile(r'(https?://[^\s]+)'),
    "split_pattern": re.compile(r'(https?://[^\s]+?)(?=https?://|$)')
}

def split_urls(content: str) -> set[str]:
    """Splits concatenated URLs in the content, capturing full URLs.

    Args:
        content (str): The string containing concatenated URLs.

    Returns:
        list[str]: A list of separated URLs.
    """
    print(content)
    # Use regex to find all URLs, including those directly concatenated
    urls = re.findall(regex_patterns['url_pattern'], content)
    
    # Further split any remaining concatenated URLs
    seperated_urls = []
    for url in urls:
        print(url)
        if url.count('http') > 1:
            sub_urls = re.findall(regex_patterns["split_pattern"], url)
            seperated_urls.extend(sub_urls)
        else:
            seperated_urls.append(url)
    
    return set(seperated_urls)
    

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


    output_path: Path | None = Path(output_file).resolve() if output_file else None

    for input_file in input_files:
        input_path: Path = Path(input_file).resolve()

        if not input_path.is_file():
            raise FileNotFoundError(f"File not found: {input_path}")

        try:
            with input_path.open("r") as file:
                # Open output file if specified
                out = output_path.open("w+") if output_path else None
                inp = input_path.open("w+")
                links: set[str] = set()
                for line in file:
                    print(line)
                    try:
                        # Split concaenated URLs dynamically
                        links.update(split_urls(line))
                    except (IOError, OSError) as io_error:
                        logging.error(
                            f"I/O error while writing to {output_file if output_file else input_file}: {io_error}"
                        )
                # Write all accumulated links to the output file at once
                if links:
                    
                    if out:
                        out.write("")  # Clear existing file contents before writing
                        out.writelines(links)
                    else:
                        inp.writelines(links)

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
