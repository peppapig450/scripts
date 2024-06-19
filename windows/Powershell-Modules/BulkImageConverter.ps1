param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Container })]
    [string] $Directory,

    [Parameter(Mandatory = $true)]
    [string[]] $ImageExtensions,

    [Parameter(Mandatory = $true)]
    [ValidateSet("jpeg", "png", "avif", "tiff", "jxl", "webp", "gif", "bmp")]
    [string] $OutputFormat,

    [string] $CustomOptions = "",

    [switch] $Recurse = $false,

    [switch] $TestRun = $false,

    [string] $MagickPath = "C:\Users\angle\scoop\apps\imagemagick\current\magick.exe"
)

# Normalize extensions to lower case for comparison
$normalizedExtensions = $ImageExtensions.ToLower()

# Handle aliases like "jpeg" and "jpg"
if ($normalizedExtensions -contains "jpeg") {
    # Replace "jpeg" with "jpg" to ensure compatability
    $normalizedExtensions += "jpg"
}

# Validate and normalize directory path
$Directory = $Directory.TrimEnd("\")
if (-not (Test-Path $Directory -PathType Container)) {
    Write-Error "Directory '$Directory' not found."
}

# Function to convert files
function ConvertFiles($dir) {
    # Get all files with the specified image extension in the directory
    $imageFiles = Get-ChildItem -Path $dir -File | Where-Object { $_.Extension.ToLower() -in $normalizedExtensions }

    if ($imageFiles.Count -eq 0) {
        Write-Host "No files found with specified image extensions in directory '$dir'."
        return
    }

    # Process each image file with this extension
    foreach ($file in $imageFiles) {
        $outputFile = Join-Path -Path $dir -ChildPath "$($file.BaseName).$OutputFormat"

    }

}
