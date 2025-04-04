function Get-RealPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        # Ensure provided path exists
        if (-Not (Test-Path $Path)) {
            throw "The path '$Path' does not exist."
        }

        # Get the full path
        $fullPath = [System.IO.Path]::GetFullPath((Resolve-Path $Path).Path)

        # Print the resolved path to the command line
        Write-Host $fullPath

        return $fullPath
    }
    catch {
        Write-Error $_.Exception.Message
        throw
    }
}