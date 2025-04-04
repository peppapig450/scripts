import re

content = """
function nvim() {
        file="$1"
        if [[ -n ${file-} ]]; then
                command nvim "$file" && echo -ne '\\e[0 q'
        else
                command nvim && echo -ne '\\e[0 q'
        fi
}

hi() {
    string="$1"
    echo "${string}"
}
"""

function_pattern = r"""
        ^\s*                        # Start of the line with optional leading whitespace
        (?:                           # Non-capturing group for the function definition
            (\w+)\s*\(\s*\)\s*      # Function name with '()'
            |                       # OR
            function\s+(\w+)\s*     # 'function' keyword followed by function name
        )
        """

# Use re.findall to find all function definitions
matches = re.finditer(function_pattern, content, re.MULTILINE | re.DOTALL | re.VERBOSE)
# group(2) is the function name

for matchNum, match in enumerate(matches, start=1):

    print ("Match {matchNum} was found at {start}-{end}: {match}".format(matchNum = matchNum, start = match.start(), end = match.end(), match = match.group()))

    for groupNum in range(0, len(match.groups())):
        groupNum = groupNum + 1

        print ("Group {groupNum} found at {start}-{end}: {group}".format(groupNum = groupNum, start = match.start(groupNum), end = match.end(groupNum), group = match.group(groupNum)))


^\s*
    (?:
        (\w+)\s*\(\s*\)\s*
        |
        function\s+(\w+)\s*
    )
    \{
    (
        [^{}]*
        (?:
            \{[^{}]*\}
            [^{}]*
        )*
    )
    \}