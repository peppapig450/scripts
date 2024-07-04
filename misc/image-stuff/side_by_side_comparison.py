from PIL import Image
import argparse


def create_side_by_side(
    image1_path, image2_path, output_path, canvas_size=(1920, 1080), buffer=10
):
    # Open the two images
    img1 = Image.open(image1_path)
    img2 = Image.open(image2_path)

    # Calculate the width of each image (half of the canvas width minus half the buffer)
    image_width = (canvas_size[0] - buffer) // 2

    # Resize images to fit within the calculated width and canvas height
    img1 = img1.resize((image_width, canvas_size[1]), Image.Resampling.LANCZOS)
    img2 = img2.resize((image_width, canvas_size[1]), Image.Resampling.LANCZOS)

    # Create a new canvas
    canvas = Image.new("RGB", canvas_size, (255, 255, 255))

    # Paste the images onto the canvas
    canvas.paste(img1, (0, 0))
    canvas.paste(img2, (image_width + buffer, 0))

    # Save the output image
    canvas.save(output_path)


def parse_arguments():
    parser = argparse.ArgumentParser(
        description="Create a side-by-side comparison image."
    )
    parser.add_argument(
        "-i",
        "--input",
        type=str,
        nargs=2,
        required=True,
        help="Paths to the two input images, space separated.",
    )
    parser.add_argument(
        "-o", "--output", type=str, required=True, help="Path to save the output image."
    )
    parser.add_argument(
        "--canvas_size",
        type=int,
        nargs=2,
        default=(1920, 1080),
        help="Optional override for the canvas size as width height.",
    )
    parser.add_argument(
        "--buffer",
        type=int,
        default=10,
        help="Optional buffer space between the two images.",
    )

    return parser.parse_args()


if __name__ == "__main__":
    args = parse_arguments()
    create_side_by_side(
        args.input[0], args.input[1], args.output, tuple(args.canvas_size), args.buffer
    )
