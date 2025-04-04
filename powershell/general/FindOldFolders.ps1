<# 
.SYNOPSIS
   Finds folders (and their contained files) that haven’t been accessed since a specified cutoff date.

.DESCRIPTION
   This script takes two parameters:
     - InputDirectory: The path to the root directory to scan.
     - CutoffDate: A DateTime value; any folder or file last accessed before this date is considered “old.”

   The script looks at every folder (including the root) and prints the folder’s full path if:
     • The folder’s own LastAccessTime is earlier than the cutoff date, OR
     • At least one file inside (recursively) has a LastAccessTime earlier than the cutoff date.

.EXAMPLE
   .\FindOldFolders.ps1 -InputDirectory "C:\Data" -CutoffDate "2023-01-01"
#>

param(
    [Parameter(Mandatory = $true, HelpMessage = "Enter the directory to search.")]
    [string]$InputDirectory,

    [Parameter(Mandatory = $true, HelpMessage = "Enter the cutoff date (e.g., 2023-01-01).")]
    [datetime]$CutoffDate
)

# Verify that the input directory exists
if (-not (Test-Path -Path $InputDirectory)) {
    Write-Error "Directory '$InputDirectory' does not exist."
    exit
}

# Retrieve all subdirectories recursively.
# Also include the root folder itself in the check.
$directories = Get-ChildItem -Path $InputDirectory -Directory -Recurse -ErrorAction SilentlyContinue
$rootFolder = Get-Item -Path $InputDirectory
$directories += $rootFolder

# Process each directory
foreach ($dir in $directories) {

    # Check if the folder itself hasn't been accessed since the cutoff date.
    $folderNotAccessed = $dir.LastAccessTime -lt $CutoffDate

    # Check for any file (within this folder and its subfolders) that hasn't been accessed.
    $files = Get-ChildItem -Path $dir.FullName -File -Recurse -ErrorAction SilentlyContinue
    $fileNotAccessed = $false

    if ($files) {
        foreach ($file in $files) {
            if ($file.LastAccessTime -lt $CutoffDate) {
                $fileNotAccessed = $true
                break  # No need to check further files in this folder.
            }
        }
    }

    # If either condition is met, print the folder's full path.
    if ($folderNotAccessed -or $fileNotAccessed) {
        Write-Output $dir.FullName
    }
}
