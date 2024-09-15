import argparse
import subprocess
import os
import logging
import requests
import shutil

logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s"
)


# TODO: separate function to create the down scaling filter
def convert_video(input_file: str, output_base: str):
    vp9_file = f"{output_base}.webm"
    h264_file = f"{output_base}.mp4"

    try:
        # Convert to VP9 WebM
        logging.info(f"Converting {input_file} to VP9 (WebM)...")
    except:
        pass


def build_downscaling_filter(width: int, height: int | None = -1):
    """Build the FFmpeg filter for down scaling video, height defaults to -1, which uses the aspect ratio to figure it out."""
    return f"scale={width}:{height}:flags=lanczos+accurate_rnd+full_chroma_int+full_chroma_inp"
