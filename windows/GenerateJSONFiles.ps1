# This script generates JSON files from the output of the Office Script: `ExtractTablesAsTitleCaseJSON.osts`
param (
    [string]$InputFilePath, # Path to the input text file
    [string]$OutputDirectory # Directory where JSON files will be saved
)

# Ensure the ouput directory exists
if (!(Test-Path $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
}

# Read the input file
$content = Get-Content -Path $InputFilePath

# Initialize variables
$filename = ""
$jsonData = @{}

# Process each line of the input file
foreach ($line in $content) {
    if ($line -match "^File: (.+)$") {
        # If there is existing data save it to a JSON file
        if ($filename -ne "" -and $jsonData.Count -gt 0) {
            $jsonOutputPath = Join-Path -Path $OutputDirectory -ChildPath $filename
            $jsonData | ConvertTo-Json -Depth 3 | Set-Content -Path $jsonOutputPath
        }

        # Start a new JSON object
        $filename = $matches[1]
        $jsonData = @{}
    }
    elseif ($line -match '"(.+?)": "(.+?)"') {
        # Extract key-value pairs and add them to the JSON object
        $key = $matches[1]
        $value = $matches[2]
        $jsonData[$key] = $value
    }
}

# Save the last JSON file
if ($filename -ne "" -and $jsonData.Count -gt 0) {
    $jsonOutputPath = Join-Path -Path $OutputDirectory -ChildPath $filename
    $jsonData | ConvertTo-Json -Depth 3 | Set-Content -Path $jsonOutputPath
}

Write-Output "JSON files have been created successfully in $OutputDirectory"
