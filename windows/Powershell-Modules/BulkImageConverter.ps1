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

# Initialize variables for summary
$filesToProcess = @()
