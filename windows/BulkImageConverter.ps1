<#
.SYNOPSIS
    Converts image files in a specified directory to a specified format using ImageMagick.

.DESCRIPTION
    This script converts image files with specified extensions in a directory (and optionally its subdirectories)
    to a specified image format using ImageMagick's convert command.

.PARAMETER Directory
    The directory containing the image files to convert.

.PARAMETER ImageExtensions
    One or more image file extensions to convert. Valid extensions include "jpeg", "jpg", "png", "gif", "bmp", etc.

.PARAMETER OutputFormat
    The output format to which the images should be converted. Valid values are "jpeg", "png", "avif", "tiff", "jxl", "webp", "gif", "bmp", "heic".

.PARAMETER CustomOptions
    Custom options (as a single string) to pass to ImageMagick's convert command (optional).
0C
.PARAMETER Recurse
    Switch to indicate whether to process files in subdirectories.

.PARAMETER TestRun
    Switch to perform a test run (prints commands that would be executed without doing the conversion).

.PARAMETER MagickPath
    The full path to ImageMagick's magick.exe executable. (Modify the default as needed.)

.PARAMETER DeleteOriginals
    Switch to indicate whether to delete original files after successful conversion.

.PARAMETER OutputDirectory
    The directory where converted files should be saved. If not specified, converted files are saved in the same directory as the originals.
    
.EXAMPLE
    .\ConvertImages.ps1 -Directory "C:\Images" -ImageExtensions "jpeg", "png" -OutputFormat "png" `
        -CustomOptions "-resize 50%" -Recurse -MagickPath "C:\Path\To\ImageMagick\magick.exe"
    Converts all JPEG and PNG images in C:\Images and its subdirectories to PNG format with resizing.

.EXAMPLE
    .\ConvertImages.ps1 -Directory "D:\Photos" -ImageExtensions "jpg" -OutputFormat "jpeg" -TestRun
    Performs a test run, printing commands that would convert all JPG images in D:\Photos to JPEG format.

.EXAMPLE
    .\ConvertImages.ps1 -Directory "E:\Pictures" -ImageExtensions "png" -OutputFormat "jpg" `
        -DeleteOriginals -OutputDirectory "E:\Converted"
    Converts all PNG images in E:\Pictures to JPEG format, deletes original files after conversion, and saves converted files in E:\Converted.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Directory containing the image files to convert.")]
    [ValidateScript({ Test-Path $_ -PathType Container })]
    [string] $Directory,

    [Parameter(Mandatory = $true, HelpMessage = "One or more image file extensions to convert.")]
    [string[]] $ImageExtensions,

    [Parameter(Mandatory = $true, HelpMessage = "Output format to which the images should be converted.") ]
    [ValidateSet("jpeg", "png", "avif", "tiff", "jxl", "webp", "gif", "bmp", "heic")]
    [string] $OutputFormat,

    [Parameter(HelpMessage = "Custom options to pass to ImageMagick's convert command (as a single string).")]
    [string] $CustomOptions = "",

    [Parameter(HelpMessage = "Process subdirectories recursively.")]
    [switch] $Recurse = $false,

    [Parameter(HelpMessage = "Perform a test run without converting files.")]
    [switch] $TestRun = $false,

    [Parameter(HelpMessage = "Full path to ImageMagick's magick.exe executable.")]
    [string] $MagickPath = "C:\Users\angle\scoop\apps\imagemagick\current\magick.exe", # Default path installed by scoop (modify)

    [Parameter(HelpMessage = "Delete original files after successful conversion.")]
    [switch] $DeleteOriginals = $false,

    [Parameter(HelpMessage = "Directory where converted files should be saved.")]
    [string] $OutputDirectory

)
# --- Pre-flight Checks ---

# Normalize the list of extensions (treating "jpeg" as "jpg" and ensuring lower-case)
$normalizedExtensions = $ImageExtensions | ForEach-Object {
    $ext = $_.ToLower()
    if ($ext -eq "jpeg") { "jpg" } else { $ext }
} | Select-Object -Unique


# Validate the primary directory (already ensured by ValidateScript)
$Directory = $Directory.TrimEnd("\\")

# If an output directory is provided, verify or create it
if ($OutputDirectory) {
    if (-not (Test-Path -LiteralPath $OutputDirectory -PathType Container)) {
        try {
            New-Item -ItemType Directory -Path $OutputDirectory -Force -ErrorAction Stop | Out-Null
            Write-Verbose "Created output directory: $OutputDirectory"
        }
        catch {
            Write-Error "Unable to create output director '$OutputDirectory': $_"
            exit 1
        }
    }
}

# Ensure that ImageMagick is available
if (-not (Test-Path -LiteralPath $MagickPath -PathType Leaf)) {
    Write-Error "ImageMagick executable not found at '$MagickPath'."
    exit 1
}


# --- Variables for Summary ---
$filesToProcess = [System.Collections.Generic.List[psobject]]::new()
$startTime = Get-Date
$convertedCount = 0
$totalOriginalSize = 0
$totalConvertedSize = 0

# --- Function: Get Files ---
function Get-Files {
    param (
        [string] $PathToSearch
    )
    try {
        # Retrieve files in the current directory
        $files = Get-ChildItem -Path $PathToSearch -File -ErrorAction Stop |
        Where-Object {
            # Compare extension (remove the period and lowercase)
            $ext = $_.Extension.TrimStart('.').ToLower()
            $normalizedExtensions -contains $ext
        }
        
    }
    catch {
        Write-Warning "Error accessing files in '$PathToSearch': $_"
        return
    }

    foreach ($file in $files) {
        # Determine the output file path:
        # If an OutputDirectory is specified, place the converted file there:
        # otherwise, use the same folder as the original file.
        if ($OutputDirectory) {
            $outputFile = Join-Path -Path $OutputDirectory -ChildPath "$($file.BaseName).$OutputFormat"
        }
        else {
            $outputFile = Join-Path -Path $file.DirectoryName -ChildPath "$($file.BaseName).$OutputFormat"
        }

        # Add file info and calculated output path to our list
        $filesToProcess.Add([PSCustomObject]@{
                InputFile  = $file.FullName
                OutputFile = $outputFile
                FileInfo   = $file
            })

        $totalOriginalSize += $file.Length
    }
}

# Get files from main directory
Get-Files -PathToSearch $Directory

# Optionally, collect files from subdirectories if -Recurse was specified
if ($Recurse) {
    try {
        $subDirs = Get-ChildItem -Path $Directory -Recurse -ErrorAction Stop
        foreach ($subDir in $subDirs) {
            Get-Files -PathToSearch $subDir.FullName
        }
    }
    catch {
        Write-Warning "Error retrieving subdirectories: $_"
    }
}

if ($filesToProcess.Count -eq 0) {
    Write-Host "No files found in '$Directory' with the specified extensions: $($normalizedExtensions -join ', ')"
    exit 0
}

# --- Conversion Loop ---
foreach ($item in $filesToProcess) {
    $inputFile = $item.InputFile
    $outputFile = $item.OutputFile

    # Build the argument list.
    # Split $CustomOptions into an array if provided.
    $customArgs = @()
    if ($CustomOptions -and $CustomOptions.Trim() -ne "") {
        # Split on whitespace; if your options may include quoted strings with spaces,
        # consider a more robust parsing method.
        $customArgs = $CustomOptions -split '\s+'
    }

    # Call ImageMagick 7
    $arguments = @("`"$inputFile`"") + $customArgs + @("`"$outputFile`"")

    if ($TestRun) {
        # Create a quoted version of the command for display purposes
        $quotedArgs = $arguments | ForEach-Object {
            if ($_ -match '\s') { '"{0}"' -f $_ } else { $_ }
        }
        Write-Host "Test Run: `"$MagickPath`" $($quotedArgs -join ' ')"
        continue
    }

    try {
        Write-Verbose "Converting '$inputFile' to '$outputFile'"
        # Start-Process will launch ImageMagick and wait until it finishes.
        $process = Start-Process -FilePath $MagickPath `
            -ArgumentList $arguments `
            -NoNewWindow -Wait -PassThru -ErrorAction Stop

        if ($process.ExitCode -ne 0) {
            Write-Warning "Conversion of '$inputFile' exited with code $($process.ExitCode)."
            continue
        }
        else {
            Write-Host "Converted: $([System.IO.Path]::GetFileName($inputFile)) → $OutputFormat"
            $convertedCount++

            # Update the converted size (if output file exists)
            if (Test-Path -LiteralPath $outputFile) {
                $totalOriginalSize += (Get-Item -LiteralPath $outputFile).Length
            }
            else {
                Write-Warning "Output file '$outputFile' not found after conversion."
            }

            # Optionally delete the original file
            if ($DeleteOriginals) {
                try {
                    Remove-Item -LiteralPath $inputFile -Force -ErrorAction Stop
                    Write-Verbose "Deleted original file: $inputFile"
                }
                catch {
                    Write-Warning "Failed to delete original file '$inputFile': $_"
                }
            }
        }
    }
    catch {
        Write-Error "Error converting '$inputFile': $_"
    }
}

# --- Summary ---
$endTime = Get-Date
$timeSpent = New-TimeSpan -Start $startTime -End $endTime
$totalSpaceSaved = $totalOriginalSize - $totalConvertedSize

Write-Host ""
Write-Host "-----------------------------"
Write-Host "        Conversion Summary"
Write-Host "-----------------------------"
Write-Host ("Files Processed:    {0}" -f $filesToProcess.Count)
Write-Host ("Files Converted:    {0}" -f $convertedCount)
Write-Host ("Output Format:      {0}" -f $OutputFormat.ToUpper())
Write-Host ("Time Elapsed:       {0}" -f $timeSpent.ToString())
Write-Host ("Original Size:      {0:N2} MB" -f ($totalOriginalSize / 1MB))
Write-Host ("Converted Size:     {0:N2} MB" -f ($totalConvertedSize / 1MB))
Write-Host ("Space Saved:        {0:N2} MB" -f ($totalSpaceSaved / 1MB))
Write-Host "-----------------------------"