import argparse
import logging
import os
import subprocess
import tempfile
from pathlib import Path

import requests
from dotenv import load_dotenv

load_dotenv()

# Fetch API Key from environment variable
IMGIX_API_KEY = os.getenv("IMGIX_API_KEY")
IMGIX_SOURCE_ID = os.getenv("IMGIX_SOURCE_ID")

if IMGIX_API_KEY is None:
    raise ValueError("IMGIX_API_KEY is not set in the .env file")

if IMGIX_SOURCE_ID is None:
    raise ValueError("IMGIX_SOURCE_ID is not set in the .env file")


class EncodingError(Exception):
    pass


class VP9EncodingError(EncodingError):
    pass


class H264EncodingError(EncodingError):
    pass


logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s"
)


def build_downscaling_filter(width: int, height: int | None = -1):
    """Build the FFmpeg filter for down scaling video, height defaults to -1, which uses the aspect ratio to figure it out."""
    return f"scale={width}:{height}:flags=lanczos+accurate_rnd+full_chroma_int+full_chroma_inp"


def convert_video(input_file: Path, output_base: Path):
    vp9_file = output_base.with_suffix(".webm")
    h264_file = output_base.with_suffix(".mp4")

    try:
        # TODO: args for optional height and width changes
        downscale_filter = build_downscaling_filter(640)

        # VP9 2-pass encoding
        logging.info(f"Converting {input_file} to VP9 (WebM)...")
        convert_video_vp9_two_pass(input_file, downscale_filter, vp9_file)

        # H264 encoding
        logging.info(f"Converting {input_file} to H264 (Mp4)...")
        convert_video_h264(input_file, downscale_filter, h264_file)

        return vp9_file, h264_file

    except VP9EncodingError as e:
        logging.error(f"VP9 encoding failed: {e}")
        raise
    except H264EncodingError as e:
        logging.error(f"H264 encoding failed: {e}")
        raise


def run_vp9_pass(
    input_file: Path,
    downscale_filter: str,
    pass_num: int,
    speed: int,
    output: Path | None = None,
):
    """Helper function to run a single VP9 pass"""
    try:
        # fmt: off
        cmd = [
            "ffmpeg",
            "-i", str(input_file),
            "-vf", downscale_filter,
            "-c:v", "vp9",
            "-r", "30",
            "-b:v", "400k",
            "-minrate", "200k",
            "-maxrate", "600k",
            "-crf", "32",
            "-map_metadata", "-1",
            "-quality", "good",
            "-speed", str(speed),
            "-pass", str(pass_num),
            "-an",
        ]
        # fmt: on

        if pass_num == 1:
            cmd.extend(["-f", "null", os.devnull])
        elif output:
            cmd.append(str(output))

        logging.info(f"Starting pass {pass_num} for {input_file}...")
        subprocess.run(cmd, check=True)
    except subprocess.CalledProcessError as e:
        logging.error(f"Error during pass {pass_num} VP9 encoding: {e}")
        raise VP9EncodingError(f"Pass {pass_num} failed") from e


def convert_video_vp9_two_pass(
    input_file: Path, downscale_filter: str, output_vp9: Path
):
    """Performs 2-pass VP9 encoding."""
    # 1st pass
    run_vp9_pass(input_file, downscale_filter, pass_num=1, speed=4, output=None)

    # 2nd pass
    run_vp9_pass(input_file, downscale_filter, pass_num=2, speed=1, output=output_vp9)

    logging.info(
        f"2-pass VP9 encoding completed for {input_file}. Output: {output_vp9}"
    )


def convert_video_h264(input_file: Path, downscale_filter: str, output_h264: Path):
    """Performs h264 encoding."""
    try:
        # fmt: off
        cmd = [
            "ffmpeg",
            "-i", str(input_file),
            "-vf", downscale_filter,
            "-c:v", "libx264",
            "-crf", "18",
            "-r", "30",
            "-preset", "veryslow",
            "-tune", "fastdecode",
            "-profile:v", "main",
            "-movflags", "+faststart",
            "-map_metadata", "-1",
            "-an",
            str(output_h264),
        ]
        # fmt: off

        subprocess.run(cmd, check=True)
    except subprocess.CalledProcessError as e:
        logging.error(f"Error during h264 encoding: {e}")
        raise H264EncodingError(f"Encoding {input_file} to {output_h264} failed") from e


def cleanup_temp_files(files: list[Path]):
    """Remove temporary files created during encoding"""
    for file in files:
        if file.exists():
            logging.info(f"Cleaning up temporary file: {file}")
            try:
                file.unlink()
            except OSError as e:
                logging.error(f"Error deleting {file}: {e}")


def upload_file_to_imgix(file_path: Path, origin_path: str):
    """Uploads a file to Imgix source"""
    url = f"https://api.imgix.com/api/v1/sources/{IMGIX_SOURCE_ID}/upload/{origin_path}"
    headers = {
        "Authorization": f"Bearer {IMGIX_API_KEY}",
        "Content-Type": "application/octet-stream",
    }

    # Read the file as binary
    with file_path.open("rb") as file_data:
        response = requests.post(url, headers=headers, data=file_data)

    if response.status_code == 200:
        logging.info(f"File {file_path} uploaded successfully.")
        logging.info(f"Asset URL: {response.json()['data']['attributes']['url']}")
    else:
        logging.error(f"Failed to upload file: {response.status_code}")
        logging.error(response.text)


def main():
    parser = argparse.ArgumentParser(
        description="Convert video to VP9 and H264, then upload to imgix."
    )
    parser.add_argument("input_file", help="Input video file")
    parser.add_argument(
        "output_base", help="Base name for the output files (extensions will be added)"
    )

    args = parser.parse_args()

    input_file = Path(args.input_file)
    output_base = args.output_base

    # Check to make sure input file exists
    if not input_file.exists():
        error_msg = f"Input file {input_file} does not exist."
        logging.error(error_msg)
        raise ValueError(error_msg)

    # Get the basenames for upload to imgix
    vp9_origin_path = f"{output_base}.webm"
    h264_origin_path = f"{output_base}.mp4"

    # create temp dir for files
    with tempfile.TemporaryDirectory() as temp_dir:
        temp_dir_path = Path(temp_dir)
        output_vp9 = Path()
        output_h264 = Path()

        try:
            # Convert video to VP9 and H264
            output_vp9, output_h264 = convert_video(
                input_file, temp_dir_path / output_base
            )

            # Upload files
            upload_file_to_imgix(output_vp9, vp9_origin_path)
            upload_file_to_imgix(output_h264, h264_origin_path)

        except Exception as e:
            logging.error(f"An error occurred: {e}")

        finally:
            # remove temp files
            cleanup_temp_files([output_vp9, output_h264])

            logging.info(f"Temporary directory {temp_dir} cleaned up.")


if __name__ == "__main__":
    main()
