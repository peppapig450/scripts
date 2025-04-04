#TODO: modify this into a script that can be used on command line or imported
def print_json_structure(json_data):
    """Prints a summary of the structure of a JSON object.

    Args:
        json_data: A Python object representing the parsed JSON data.
    """

    if isinstance(json_data, dict):
        print("Object:")
        for key, value in json_data.items():
            print(f"  - Key: {key} (type: {type(value).__name__})")
            print_json_structure(value)  # Recursive call for nested objects
    elif isinstance(json_data, list):
        print("Array:")
        if json_data:  # Check if list is not empty
            sample_element = json_data[0]
            print(f"  - Element type: {type(sample_element).__name__}")
            print_json_structure(sample_element)  # Recursive call for sample element
        else:
            print("  - Empty array")
    else:
        print(f"Value: {json_data} (type: {type(json_data).__name__})")
