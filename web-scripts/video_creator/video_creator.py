import argparse
import subprocess
import os
import logging
import requests
import shutil

from dotenv import load_dotenv

load_dotenv()


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


def convert_video(input_file: str, output_base: str):
    vp9_file = f"{output_base}.webm"
    h264_file = f"{output_base}.mp4"

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
    input_file: str,
    downscale_filter: str,
    pass_num: int,
    speed: int,
    output: str | None = None,
):
    """Helper function to run a single VP9 pass"""
    try:
        # fmt: off
        cmd = [
            "ffmpeg",
            "-i", input_file,
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
            cmd.append(output)

        logging.info(f"Starting pass {pass_num} for {input_file}...")
        subprocess.run(cmd, check=True)
    except subprocess.CalledProcessError as e:
        logging.error(f"Error during pass {pass_num} VP9 encoding: {e}")
        raise VP9EncodingError(f"Pass {pass_num} failed") from e


def convert_video_vp9_two_pass(input_file: str, downscale_filter: str, output_vp9: str):
    """Performs 2-pass VP9 encoding."""
    # 1st pass
    run_vp9_pass(input_file, downscale_filter, pass_num=1, speed=4, output=None)

    # 2nd pass
    run_vp9_pass(input_file, downscale_filter, pass_num=2, speed=1, output=output_vp9)

    logging.info(
        f"2-pass VP9 encoding completed for {input_file}. Output: {output_vp9}"
    )


def convert_video_h264(input_file: str, downscale_filter: str, output_h264: str):
    """Performs h264 encoding."""
    try:
        # fmt: off
        cmd = [
            "ffmpeg",
            "-i", input_file,
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
            output_h264,
        ]
        # fmt: off
        
        subprocess.run(cmd, check=True)
    except subprocess.CalledProcessError as e:
        logging.error(f"Error during h264 encoding: {e}")
        raise H264EncodingError(f"Encoding {input_file} to {output_h264} failed") from e
