<#
.SYNOPSIS 
Converts image files in a specified directory to a specified format using ImageMagick.

.DESCRIPTION
This script converts image files with specified extensions in a directory (and optionally its subdirectories) to a specified image format using ImageMagick's convert command.

.PARAMETER Directory
Specified the directory containing the image files to convert.

.PARAMETER ImageExtensions
Specifies one or more image file extensions to convert. Valid extensions include "jpeg", "jpg", "png", "gif", "bmp".

.PARAMETER OutputFormat
Specifies the output format to which the images should be converted. Valid values are "jpeg", "jpg", "png", "gif", "bmp".

.PARAMETER CustomOptions
Specifies any custom options to pass to ImageMagick's convert command (optional).

.PARAMETER RecurseSubdirectories
Switch to indicate whether to recurse through subdirectories of the specified directory for image conversion.

.PARAMETER TestRun
Switch to perform a test run. Prints commands that would be executed without actually converting images.

.PARAMETER MagickPath
Specifies the full path to the ImageMagick 'magick.exe' executable.

.PARAMETER DeleteOriginals
Switch to indicate whether to delete original files after successful conversion.

.PARAMETER OutputDirectory
Specifies the directory where converted files should be saved. If not specified, files will be saved in the same directory as the original files.

.EXAMPLE
.\ConvertImages.ps1 -Directory "C:\Images" -ImageExtensions "jpeg", "png" -OutputFormat "png" -CustomOptions "-resize 50%" -RecurseSubdirectories -MagickPath "C:\Path\To\ImageMagick\magick.exe"
Converts all JPEG and PNG images in C:\Images and its subdirectories to PNG format with resizing, using ImageMagick.

.EXAMPLE
.\ConvertImages.ps1 -Directory "D:\Photos" -ImageExtensions "jpg" -OutputFormat "jpeg" -TestRun
Performs a test run, printing commands to convert all JPG images in D:\Photos to JPEG format using ImageMagick.

.EXAMPLE
.\ConvertImages.ps1 -Directory "E:\Pictures" -ImageExtensions "png" -OutputFormat "jpg" -DeleteOriginals -OutputDirectory "E:\Converted"
Converts all PNG images in E:\Pictures to JPEG format, deletes original files after conversion, and saves converted files in E:\Converted directory.

.NOTES
- Ensure ImageMagick (magick.exe) is installed and accessible in the specified path.
- Output files will be saved in the specified OutputDirectory or in the same directory structure as the original images if not specified.
#>
#TODO: not working of course, love powershell!
param(
    [Parameter(Mandatory = $true, HelpMessage = "Directory containing the image files to convert.")]
    [ValidateScript({ Test-Path $_ -PathType Container })]
    [string] $Directory,

    [Parameter(Mandatory = $true, HelpMessage = "One or more image file extensions to convert.")]
    [string[]] $ImageExtensions,

    [Parameter(Mandatory = $true, HelpMessage = "Output format to which the images should be converted.") ]
    [ValidateSet("jpeg", "png", "avif", "tiff", "jxl", "webp", "gif", "bmp")]
    [string] $OutputFormat,

    [string] $CustomOptions = "",

    [switch] $Recurse = $false,

    [switch] $TestRun = $false,

    [string] $MagickPath = "C:\Users\angle\scoop\apps\imagemagick\current\magick.exe", # Default path installed by scoop (modify)

    [switch] $DeleteOriginals = $false,

    [string] $OutputDirectory

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
$filesToProcess = @{}
$startTime = Get-Date
$convertedCount = 0
$totalOriginalSize = 0
$totalConvertedSize = 0

# Function to collect files to process
function CollectFiles($dir) {
    # Get all files with the specified image extension in the directory
    $imageFiles = Get-ChildItem -Path $dir -File | Where-Object {
        $normalizedExtensions -contains $_.Extension.TrimStart('.').ToLower()
    }

    if ($imageFiles.Count -eq 0) {
        Write-Host "No files found with specified image extensions in directory '$dir'."
        return        
    }

    # Add files to process list
    foreach ($file in $imageFiles) {
        $outputFile = Join-Path -Path $dir -ChildPath "$($file.BaseName).$OutputFormat"

        # Check if the file already exists and add
        if (-not $filesToProcess.ContainsKey($file.FullName)) {
            $filesToProcess.Add($file.FullName, @{
                    File       = $file
                    OutputFile = $outputFile
                })
        }

        # Calculate total original size
        $totalOriginalSize += $file.Length
    }
}

# Collect files from main directory
CollectFiles $Directory

# Optionally collect files from subdirectories
if ($Recurse) {
    $subdirectories = Get-ChildItem -Path $Directory -Directory -Recurse
    foreach ($subdir in $subdirectories) {
        CollectFiles $subdir.FullName
    }
}

# Process files
foreach ($fileInfo in $filesToProcess) {
    $file = $fileInfo.files
    $outputFile = $fileInfo.OutputFile

    $command = "$MagickPath convert `"$($file.FullName)`" $CustomOptions `"$outputFile`""

    if ($TestRun) {
        Write-Host "Test Run: $command"
    }
    else {
        # Execute the ImageMagick command
        try {
            Invoke-Expression -Command $command -ErrorAction Stop
            Write-Host "Converted $($file.Name) to $($OutputFormat.ToUpper()) format."
            $convertedCount++

            # Calulate total converted size
            $totalConvertedSize += (Get-Item $outputFile).Length

            # Delete original file if specified
            if ($DeleteOriginals) {
                Remove-Item $file.FullName -Force
                Write-Verbose "Deleted $($file.Name) after conversion."
            }
        }
        catch {
            Write-Error "Failed to convert $($file.Name). Error: $_"
        }
    }
}

# Calculate time spent
$endTime = Get-Date
$timeSpent = New-TimeSpan -Start $startTime -End $endTime

# Calculate space saved
$totalSpaceSaved = $totalOriginalSize - $totalConvertedSize

# Summary
Write-Host "-----------------------------"
Write-Host "Conversion Summary"
Write-Host "-----------------------------"
Write-Host "Files Converted: $convertedCount"
Write-Host "Image Formats Converted To: $($OutputFormat.ToUpper())"
Write-Host "Total Time Spent: $($timeSpent.Hours) hours, $($timeSpent.Minutes) minutes, $($timeSpent.Seconds) seconds"
Write-Host "Total Space Saved: $($totalSpaceSaved / 1MB) MB"