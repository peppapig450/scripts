# This script generates JSON files from the output of the Office Script: `ExtractTablesAsTitleCaseJSON.osts`
param (
    [string]$InputFilePath, # Path to the input text file
    [string]$OutputDirectory # Directory where JSON files will be saved
)

# Validate input parameters
if ([string]::IsNullOrWhiteSpace($InputFilePath)) {
    Write-Error "InputFilePath is "
}

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    Write-Error "OutputDirectory is required and cannot be empty."
    exit 1
}

# Ensure the input file exists
if (!(Test-Path $InputFilePath)) {
    Write-Error "The input file '$InputFilePath' does not exist."
    exit 1
}

# Ensure the ouput directory exists
if (!(Test-Path $OutputDirectory)) {
    try {
        New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
    }
    catch {
        Write-Error "Failed to create output directory '$OutputDirectory'."
        exit 1
    }
}

# Read the input file
try {
    $content = Get-Content -Path $InputFilePath
}
catch {
    Write-Error "Failed to read the input file '$InputFilePath'."
    exit 1
}


# Initialize variables
$filename = ""
$jsonData = @{}

# Process each line of the input file
foreach ($line in $content) {
    if ($line -match "^File: (.+)$") {
        # If there is existing data save it to a JSON file
        if ($filename -ne "" -and $jsonData.Count -gt 0) {
            $jsonOutputPath = Join-Path -Path $OutputDirectory -ChildPath $filename
            try {
                $jsonData | ConvertTo-Json -Depth 3 | Set-Content -Path $jsonOutputPath
            }
            catch {
                Write-Error "Failed to write to JSON file '$jsonOutputPath'."
                exit 1
            } 

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
# Save the last JSON file
if ($filename -ne "" -and $jsonData.Count -gt 0) {
    $jsonOutputPath = Join-Path -Path $OutputDirectory -ChildPath $filename
    try {
        $jsonData | ConvertTo-Json -Depth 3 | Set-Content -Path $jsonOutputPath -Encoding UTF8
    }
    catch {
        Write-Error "Failed to write to JSON file '$jsonOutputPath'."
        exit 1
    }
}

Write-Output "JSON files have been created successfully in $OutputDirectory"
