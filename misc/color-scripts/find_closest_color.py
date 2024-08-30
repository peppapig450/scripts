from colormath.color_objects import sRGBColor, LabColor
from colormath.color_conversions import convert_color
from colormath.color_diff import delta_e_cie2000, delta_e_cmc
from enum import StrEnum
import numpy as np
import re

class Formula(StrEnum):
    CIE2000 = "cie2000"
    CMC = "cmc"

def parse_color(color: str) -> sRGBColor:
    """
    Parses a color string and converts it to an sRGBColor object.

    Supports hex (e.g., #RRGGBB, #RGB), RGB (e.g., rgb(r, g, b)), 
    and RGBA (e.g., rgba(r, g, b, a)) formats.

    Args:
        color (str): The color string to parse.

    Returns:
        sRGBColor: The sRGBColor object representing the input color.

    Raises:
        ValueError: If the color format is not supported.
    """
    color = color.strip()
    if color.startswith("#"):
        try:
            return sRGBColor.new_from_rgb_hex(color)
        except ValueError:
            raise ValueError(f"Invalid hex code format: {color}")
    if color.startswith('rgb'):
        numbers = list(map(float, re.findall(r'\d+', color)))
        if len(numbers) == 3:
            return sRGBColor(numbers[0] / 255.0, numbers[1] / 255.0, numbers[2] / 255.0, is_upscaled=True)
        elif len(numbers) == 4:  # Ignore alpha in RGBA
            return sRGBColor(numbers[0] / 255.0, numbers[1] / 255.0, numbers[2] / 255.0, is_upscaled=True)
        else:
            raise ValueError(f"Invalid RGB/RGBA format: {color}")
    else:
        raise ValueError(f"Unsupported color format: {color}")
    
def calculate_color_difference(color1: sRGBColor, color2: sRGBColor, formula: Formula) -> float:
    """
    Calculates the color difference between two sRGBColor objects using a specified Delta E formula.

    Converts sRGBColor objects to LAB color space and computes perceptual differences using the chosen formula.

    Args:
        color1 (sRGBColor): The first color object.
        color2 (sRGBColor): The second color object.
        formula (Formula): The Delta E formula to use.

    Returns:
        float: The color difference between the two colors using the specified formula.

    Raises:
        ValueError: If the formula is not supported.
    """
    lab1 =  convert_color(color1, LabColor)
    lab2 = convert_color(color2, LabColor)
    
    if formula == Formula.CIE2000:
        return delta_e_cie2000(lab1, lab2)
    elif formula == Formula.CMC:
        return delta_e_cmc(lab1, lab2)
    else:
        raise ValueError(f"Unsupported formula: {formula}")
    
def find_closest_color(input_color: str, color_list: list[str]) -> str | None:
    """
    Finds the closest color from a list of hex color codes to the input color.

    Uses the geometric mean of Delta E CIEDE2000 and Delta E CMC to determine the closest match.

    Args:
        input_color (str): The input color string in a supported format.
        color_list (list[str]): A list of hex color strings to compare against.

    Returns:
        Union[str, None]: The closest hex color string from the list, or None if no match is found.
    """
    input_rgb = parse_color(input_color)
    
    delta_e_2000_values = [calculate_color_difference(input_rgb, parse_color(c), formula=Formula.CIE2000) for c in color_list]
    delta_e_cmc_values  = [calculate_color_difference(input_rgb, parse_color(c), formula=Formula.CMC) for c in color_list]
    
    combined_values = [np.sqrt(delta_e_2000_value * delta_e_cmc_value) for delta_e_2000_value, delta_e_cmc_value in zip(delta_e_2000_values, delta_e_cmc_values)]

    # Find the index of the smallest combined item
    closest_index = combined_values.index(min(combined_values))
    
    return color_list[closest_index]

def main():
    """
    Main function to handle user input and find the closest color.

    Prompts the user to enter a color and a list of colors (as hex codes), 
    then finds and displays the closest matching color from the list.
    """
    input_color = input("Enter a color (hex, RGB, RGBA): ").strip()
    color_list = input("Enter a list of hex colors (comma-separated, e.g., #FF5733, #3498db): ").strip().split(',')
    
    try:
        closest = find_closest_color(input_color, [color for color in color_list])
        print(f"The closest color to {input_color} is {closest}.")
    except ValueError as e:
        print(f"Error: {e}")
        
if __name__ == "__main__":
    main()