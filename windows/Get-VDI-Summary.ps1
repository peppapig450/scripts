# Function to execute EXE, capture output, and write to temporary file
function Execute-And-WriteTempFile {
    param(
        [string]$exePath,
        [string[]]$arguments
    )

    # Create temporary file
    $tempFile = New-TemporaryFile
    $tempFilePath = $tempFile.FullName

    # Start the process and redirect output
    Start-Process -FilePath $exePath -ArgumentList $arguments -RedirectStandardOutput $tempFilePath -Wait

    # Return the temporary file path
    return $tempFilePath
}

# Function to extrat detaisl from each entry
function Get-VdiDetails {
    param(
        [string]$entry
    )

    # Extract UUID using regex
    $uuid = if ($entry -match 'UUID:\s+(.+?)$') { $Matches[1].Trim() } else { "" }

    # Extract location line starting with "Location:"
    $locationLine = $entry | Where-Object { $_ -match '^Location:' }
 
    # Extract location by removing leading spaces and "Location:"
    $location = if ($locationLine) { ($locationLine -replace '^Location:\s+', '').Trim() } else { "" }
 
    # Extract capacity line starting with "Capacity:"
    $capacityLine = $entry | Where-Object { $_ -match '^Capacity:' }
 
    # Extract capacity by removing leading spaces and replacing MBytes to MB
    $capacity = if ($capacityLine) { ($capacityLine -replace '^Capacity:\s+', '') -replace ' MBytes$', 'MB' } else { "" }

    # Return an object with extracted details
    return New-Object psobject -Property @{
        UUID     = $uuid
        Location = $location
        Capacity = $capacity
    }
}

# Set arguments and path to VboxManage for getting the list of vdi's
$exePath = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
$arguments = "list hdds"

# Execute 'vboxmanage list hdds' and get temp file path
$tempFilePath = Execute-And-WriteTempFile -exePath $exePath -arguments $arguments

# Now we can parse the output to get the columnated list
$vdiContentList = Get-Content $tempFilePath 

# Process each VDI entry
$vdiDetails = $vdiContentList | ForEach-Object { Get-VdiDetails $_ }

# Display the results in a table format
$vdiDetails | Format-Table -AutoSize UUID, Location, Capacity
