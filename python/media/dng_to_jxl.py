import argparse
import logging
import subprocess
from pathlib import Path
from shutil import which


class ConversionError(Exception):
    pass


def setup_logging(verbose: bool):
    """Set up logging configuration based on verbosity level."""
    log_level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(
        level=log_level,
        format="%(asctime)s - %(levelname)s - %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )


def check_commands():
    """Make sure that the commands we need are runnable."""
    commands = ["cjxl", "magick", "exiftool"]

    for command in commands:
        if which(command) is None:
            logging.error(f"Command '{command}' not found on PATH.")
            raise ValueError(f"Command '{command}' not found")


def cleanup_file(file_path: Path):
    """Delete the intermediate files if they exist, raise Error otherwise"""
    if file_path.exists():
        try:
            file_path.unlink()
            logging.info(f"Deleted intermediate metadata file: {str(file_path)}")
        except OSError as e:
            logging.error(f"Error deleting intermediate metadata file: {e}")


def convert_dng_to_png(input_file: str, intermediate_file: str):
    """Convert DNG to PNG using ImageMagick with maximum quality."""
    try:
        subprocess.run(
            [
                "magick",
                "convert",
                input_file,
                "-quality",
                "100",
                "-define",
                "png:compression-level=0",
                intermediate_file,
            ],
            check=True,
        )
        logging.info(f"Converted {input_file} to lossless PNG.")
    except subprocess.CalledProcessError as e:
        logging.error(f"Error during DNG to PNG conversion {e}")
        raise ConversionError from e


def copy_metadata(input_file: str, intermediate_file: str, verbose: bool):
    """Copy metadata from original DNG to intermediate PNG using ExifTool."""
    try:
        result = subprocess.run(
            [
                "exiftool",
                "-ee3",
                "-api",
                "requestall=3",
                "-api",
                "largefilesupport",
                "-tagsFromFile",
                input_file,
                "-All:All",
                intermediate_file,
            ],
            capture_output=True,
            text=True,
            check=True,
        )
        logging.info(f"Copied metadata from {input_file} to PNG.")
        if verbose:
            logging.debug(f"Metadata copy output:\n{result.stdout}")
    except subprocess.CalledProcessError as e:
        logging.error(f"Erorr during metadata copying: {e}")
        if e.stderr:
            logging.debug(f"Error output:\n{e.stderr}")
        raise ConversionError from e


def convert_png_to_jxl(intermediate_file: str, output_file: str):
    """Convert PNG to JXL using cjxl."""
    try:
        subprocess.run(
            ["cjxl", "-e", "10", intermediate_file, output_file],
            check=True,
        )
        logging.info(f"Converted PNG to {output_file} as JXL.")
    except subprocess.CalledProcessError as e:
        logging.error(f"Error during PNG to JXL conversion: {e}")
        raise ConversionError from e


def print_size_info(input_file: str, output_file: str):
    """Print file size information and percentage saved."""
    input_size = Path(input_file).stat().st_size
    output_size = Path(output_file).stat().st_size
    percent_saved = ((input_size - output_size) / input_size) * 100

    logging.info(f"Original size: {input_size / (1024 * 1024):.2f} MB")
    logging.info(f"Output size: {output_size / (1024 * 1024):.2f} MB")
    logging.info(f"Space saved: {percent_saved:.2f}%")


def main():
    parser = argparse.ArgumentParser(
        description="Convert DNG to JXL preserving color profile and orientation."
    )
    parser.add_argument("input_file", help="Path to the input DNG file.")
    parser.add_argument("output_file", help="Desired output JXL file name.")
    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help="Enable verbose mode to display detailed information.",
    )

    args = parser.parse_args()

    # Set up logging
    setup_logging(args.verbose)

    # Define intermediate PNG file name
    intermediate_file = "intermediate.png"

    try:
        # make sure the commands we need are runnable
        check_commands()

        # Convert DNG to PNG losslessly
        convert_dng_to_png(args.input_file, intermediate_file)

        # Copy metadata from the DNG to the PNG for preserving color profile and orientation
        copy_metadata(args.input_file, intermediate_file, args.verbose)

        # Convert PNG to JXL
        convert_png_to_jxl(intermediate_file, args.output_file)

        # Display file size info and size percentage saved
        print_size_info(args.input_file, args.output_file)
    except ValueError as e:
        logging.error(f"Something went wrong while checking the commands we need: {e}")
    except ConversionError as e:
        logging.error(f"Something went wrong while handling the conversion: {e}")
    finally:
        # Cleanup intermediate file
        intermediate = Path(intermediate_file)
        intermediate_original_meta = Path(f"{intermediate_file}_original")

        cleanup_file(intermediate)
        cleanup_file(intermediate_original_meta)


if __name__ == "__main__":
    main()
