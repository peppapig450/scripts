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
def convert_video(input_file: str, output_base: str, height_width: tuple[int, int]):
    vp9_file = f"{output_base}.webm"
    h264_file = f"{output_base}.mp4"

    try:
        # Convert to VP9 WebM
        logging.info(f"Converting {input_file} to VP9 (WebM)...")
    except:
        pass
