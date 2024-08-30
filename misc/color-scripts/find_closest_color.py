from skimage.color import rgb2lab, deltaE_cmc, deltaE_ciede2000
import numpy as np
from statistics import geometric_mean
import re
from typing import Any
from numpy.typing import NDArray

type RGBTuple = tuple[int, ...] | tuple[int, int, int]

regex_patterns = {
    "hex": re.compile(r'^#?([A-Fa-f0-9]{6})$'),
    "rgb": re.compile(r'^\(?\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*\)?$')
}

def hex_to_rgb(hex_code: str) -> RGBTuple:
    """Convert a hex code to an RGB tuple"""
    hex_code = hex_code.lstrip('#')
    return tuple(int(hex_code[i:i + 2], 16) for i in (0, 2, 4))

def rgb_to_lab(rgb: RGBTuple):
    """Convert an RGB tuple to LAB color space."""
    rgb_normalized = np.array(rgb) / 255.0
    return rgb2lab(rgb_normalized[np.newaxis, np.newaxis, :])[0][0]

def validate_rgb(rgb: str | RGBTuple) -> RGBTuple:
    """Validate and convert an input string into an RGB tuple if possible."""
    if isinstance(rgb, tuple) and len(rgb) == 3 and all(0 <= val <= 255 for val in rgb):
        return rgb
    elif isinstance(rgb, str):
        if match := regex_patterns["rgb"].match(rgb):
            rgb_tuple = tuple(map(int, match.groups()))
            if all(0 <= val <= 255 for val in rgb_tuple):
                return rgb_tuple
    raise ValueError("Invalid RGB input. Expected a tuple of three integers between 0 and 255 or a string formatted as 'R, G, B'.")
            
def validate_hex(hex_code: str) -> str:
    """Validate if a string is a valid hex color code."""
    if isinstance(hex_code, str) and regex_patterns["hex"].match(hex_code):
        return hex_code
    raise ValueError("Invalid hex input. Expected a hex string like '#RRGGBB'.")

def closest_color(input_color: str | RGBTuple | Any, color_list: list[str]):
    """Find the closest color in a list of hex codes to the input RGB or hex color."""
    # Convert input color to RGB and LAB
    if isinstance(input_color, str) and input_color.startswith('#'):
        input_rgb = hex_to_rgb(validate_hex(input_color))
    elif isinstance(input_color, str) or isinstance(input_color, tuple):
        input_rgb = validate_rgb(input_color)
    else:
        raise ValueError("Invalid input color format.")
    
    input_lab = rgb_to_lab(input_rgb)
    
    # Convert the color list to LAB
    colors_rgb = [hex_to_rgb(validate_hex(hex_code)) for hex_code in color_list]
    colors_lab = [rgb_to_lab(rgb) for rgb in colors_rgb]
    
    # Calculate Delta E CMC and Delta E 2000 for each color
    delta_e_cmc = [deltaE_cmc(input_lab, lab) for lab in colors_lab]
    delta_e_2000 = [deltaE_ciede2000(input_lab, lab) for lab in colors_lab]
    
    # Calculate geometric mean of both Delta E values using statistics.geometric_mean
    geometric_means = [geometric_mean([cmc, de2000]) for cmc, de2000 in zip(delta_e_cmc, delta_e_2000)]
    
    # Find the index of the closest color
    closest_idx = np.argmin(geometric_means)
    
    # Print the results
    print("Closest color using Delta E CMC:")
    print(f"Hex: {color_list[np.argmin(delta_e_cmc)]}, RGB: {colors_rgb[np.argmin(delta_e_cmc)]}, Delta E CMC: {min(delta_e_cmc)}")

    print("\nClosest color using Delta E 2000:")
    print(f"Hex: {color_list[np.argmin(delta_e_2000)]}, RGB: {colors_rgb[np.argmin(delta_e_2000)]}, Delta E 2000: {min(delta_e_2000)}")

    print("\nClosest color using Geometric Mean of Delta E CMC and Delta E 2000:")
    print(f"Hex: {color_list[closest_idx]}, RGB: {colors_rgb[closest_idx]}, Geometric Mean: {geometric_means[closest_idx]}")
    
def main():
    """Main function to handle user input and run the closest color calculation."""
    print("Enter the input color (hex code like '#RRGGBB' or RGB as 'R, G, B'):")
    input_color = input().strip()

    print("Enter a list of hex codes to compare against, separated by commas (e.g., '#FF5733, #33FF57, #3357FF'):")
    color_list = [color.strip() for color in input().split(',')]

    try:
        closest_color(input_color, color_list)
    except ValueError as e:
        print(f"Error: {e}")
        
if __name__ == "__main__":
    main()