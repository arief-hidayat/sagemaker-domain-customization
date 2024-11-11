#!/bin/bash

# Check if sparkmagic is installed via pip
if ! pip show sparkmagic &> /dev/null; then
    echo "Sparkmagic is not installed via pip. Please install it first."
    exit 1
fi

# Get the location of sparkmagic installation
sparkmagic_location=$(pip show sparkmagic | grep "Location:" | cut -d " " -f 2)

# Construct the full path to the command.py file
file_path="${sparkmagic_location}/sparkmagic/livyclientlib/command.py"


# Check if the file exists
if [ -f "$file_path" ]; then
    # Create a backup of the original file
    cp "$file_path" "${file_path}.bak"
    # Find the line number of 'class Command(ObjectWithGuid):'
    class_line=$(grep -n "class Command(ObjectWithGuid):" "$file_path" | cut -d: -f1)

    # Append the new function to the file
    new_function=$(cat << EOF


import re

def adjust_line_number(error_string, adjustment=-3):
    def replace_line_number(match):
        line_num = int(match.group(1))
        new_line_num = max(1, line_num + adjustment)
        return f", line {new_line_num},"

    pattern = r', line (\d+),'
    adjusted_string = re.sub(pattern, replace_line_number, error_string)
    return adjusted_string

def process_error_strings(error_strings, adjustment=-3):
    adjusted_strings = [adjust_line_number(error, adjustment) for error in error_strings]
    return "".join(adjusted_strings)

def indent_multiline_string(text, indent=4):
    """
    Indent a multi-line string.

    Args:
    text (str): The multi-line string to indent.
    indent (int): The number of spaces to use for indentation (default is 4).

    Returns:
    str: The indented multi-line string.
    """
    # Split the text into lines
    lines = text.split('\n')

    # Create the indentation string
    indent_str = ' ' * indent

    # Indent each line, except for empty lines
    indented_lines = [indent_str + line if line.strip() else line for line in lines]

    # Join the indented lines back into a single string
    return '\n'.join(indented_lines)

def wrap_with_try(code):
    return f"""
import logging
try:
{indent_multiline_string(code)}
except Exception as e:
    logging.error(e, exc_info=True)
    raise e
    """


EOF
)
    # Insert the new function before 'class Command(ObjectWithGuid):'
    sed -i "$((class_line - 1))r /dev/stdin" "$file_path" <<< "$new_function"

    # Replace the specified line
    sed -i 's/self\.code = textwrap\.dedent(code)/self.code = wrap_with_try(textwrap.dedent(code))/' "$file_path"
    sed -i 's/""\.join(statement_output["traceback"])/process_error_strings(statement_output["traceback"])/' "$file_path"
    chmod 664 "$file_path"
    echo "Operations completed successfully."
else
    echo "File not found: $file_path"
    exit 1
fi
