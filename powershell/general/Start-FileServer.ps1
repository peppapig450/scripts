<# 
.SYNOPSIS
   Wrapper script for the Go file upload server. (https://github.com/peppapig450/iOSFileUploadServer.git)
   
.DESCRIPTION
   This PowerShell script serves as a wrapper for the Go file upload server, making it easier to start and configure.
   It can also generate a QR code for easy access from mobile devices.
   
.PARAMETER ExecutablePath
   Path to the Go executable. Default is ".\fileserver.exe".
   
.PARAMETER UploadDir
   Directory to save uploaded files. Default is "uploads".
   
.PARAMETER Port
   Port to run the server on. Default is 9090.
   
.PARAMETER MaxSizeMB
   Maximum upload file size in MB. Default is 50MB.
   
.PARAMETER Debug
   Enable debug logging.
   
.PARAMETER AuthToken
   Authentication token. If not provided, will use UPLOAD_SERVER_AUTHTOKEN environment variable or prompt for one.
   
.PARAMETER GenerateQR
   Generate a QR code for the server URL.
   
.PARAMETER InternalIP
   The internal IP address to use for the QR code URL. If not specified, attempts auto-detection.
   
.EXAMPLE
   .\Start-FileServer.ps1 -Port 8080 -UploadDir "C:\uploads" -GenerateQR
#>

[CmdletBinding()]
param(
    [string]$ExecutablePath = ".\upload-server.exe",
    [string]$UploadDir = "uploads",
    [int]$Port = 9090,
    [int]$MaxSizeMB = 50,
    [string]$AuthToken,
    [switch]$GenerateQR,
    [string]$InternalIP
)


# Verify executable exists
$ResolvedPath = Resolve-Path (Join-Path $PSScriptRoot $ExecutablePath) -ErrorAction SilentlyContinue
if (-not $ResolvedPath -or -not (Test-Path $ResolvedPath)) {
    Write-Warning "The default executable '$ExecutablePath' was not found in the script's directory."
    if ($env:UPLOAD_SERVER_PATH -and (Test-Path $env:UPLOAD_SERVER_PATH)) {
        Write-Verbose "Using executable from environment variable: $env:UPLOAD_SERVER_PATH"
        $ExecutablePath = $env:UPLOAD_SERVER_PATH
    }
    else {
        Write-Error "The executable file '$ExecutablePath' was not found. Please provide the correct path using -ExecutablePath or set UPLOAD_SERVER_PATH environment variable."
        exit 1
    }
}
else {
    $ExecutablePath = $ResolvedPath
}

function Get-LocalIPAddress {
    try {
        # Get network adapters that are up
        $adapters = Get-NetAdapter | Where-Object { 
            $_.Status -eq 'Up' -and $_.InterfaceOperationalStatus -eq 1 
        } | Sort-Object -Property { 
            # Prioritize Ethernet over Wi-Fi, then by InterfaceIndex (lower is often primary)
            if ($_.InterfaceDescription -like '*Ethernet*') { 0 } else { 1 }
        }

        $ipAddresses = @()
        foreach ($adapter in $adapters) {
            # Get IPv4 addresses for the adapter
            $ips = Get-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -AddressFamily IPv4 |
            Where-Object {
                $_.AddressState -eq 'Preferred' -and
                $_.IPAddress -ne '127.0.0.1' -and
                $_.IPAddress -notlike '169.254.*'
            }

            foreach ($ip in $ips) {
                # Check if IP is in a private subnet
                $ipString = $ip.IPAddress
                $isPrivate = $ipString -match '^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.)'

                # Add IP with metadata for sorting
                $ipAddresses += [PSCustomObject]@{
                    IPAddress      = $ipString
                    InterfaceIndex = $ip.InterfaceIndex
                    InterfaceAlias = $adapter.InterfaceAlias
                    PrefixOrigin   = $ip.PrefixOrigin
                    IsPrivate      = $isPrivate
                    IsEthernet     = $adapter.InterfaceDescription -like '*Ethernet*'
                    HasGateway     = $null -ne (Get-NetRoute -InterfaceIndex $adapter.InterfaceIndex -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue)
                }
            }
        }

        # Sort IPs: prefer DHCP, private subnets, Ethernet, and interfaces with a gateway
        $selectedIp = $ipAddresses | Sort-Object -Property @{
            Expression = { if ($_.PrefixOrigin -eq 'Dhcp') { 0 } else { 1 } } # DHCP first
        }, @{
            Expression = { if ($_.IsPrivate) { 0 } else { 1 } }               # Private subnets
        }, @{
            Expression = { if ($_.IsEthernet) { 0 } else { 1 } }              # Ethernet over Wi-Fi
        }, @{
            Expression = { if ($_.HasGateway) { 0 } else { 1 } }              # Has default gateway
        } | Select-Object -First 1

        if ($selectedIp) {
            Write-Verbose "Selected IP: $($selectedIp.IPAddress) (Interface: $($selectedIp.InterfaceAlias), Origin: $($selectedIp.PrefixOrigin))"
            return $selectedIp.IPAddress
        }
        else {
            Write-Warning "No suitable IPv4 address found. Please specify with -InternalIP parameter."
            return $null
        }
    }
    catch {
        Write-Warning "Failed to determine IP address: $_"
        return $null
    }
}

function Import-QRCoder {
    [CmdletBinding()]
    param (
        [string]$Version = "1.6.0", # Latest known version as of April 2025
        [string]$Scope = "CurrentUser"
    )

    try {
        # Ensure TLS 1.2 is enabled
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

        # Ensure NuGet package provider is installed
        Write-Verbose "Checking for NuGet package provider..."
        if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
            Write-Verbose "Installing NuGet package provider..."
            Install-PackageProvider -Name NuGet -Force -Scope $Scope -ErrorAction Stop
        }

        # Register NuGet package source if not present
        $nugetSource = "https://api.nuget.org/v3/index.json"
        if (-not (Get-PackageSource | Where-Object { $_.Location -eq $nugetSource })) {
            Write-Verbose "Registering NuGet package source..."
            Register-PackageSource -Name NuGet -Location $nugetSource -ProviderName NuGet -ErrorAction Stop
        }

        # Check if QRCoder is installed
        $package = Get-Package -Name QRCoder -ProviderName NuGet -ErrorAction SilentlyContinue | Where-Object { $_.Version -eq $Version }
        if (-not $package) {
            Write-Verbose "Installing QRCoder version $Version..."
            Install-Package -Name QRCoder -ProviderName NuGet -Scope $Scope -RequiredVersion $Version -Force -ErrorAction Stop
        }
        else {
            Write-Verbose "QRCoder version $Version is already installed."
        }

        # Locate the QRCoder DLL
        $package = Get-Package -Name QRCoder -ProviderName NuGet | Where-Object { $_.Version -eq $Version }
        if (-not $package) {
            throw "Failed to locate installed QRCoder package."
        }

        $packagePath = Split-Path $package.Source -Parent
        $dllPath = Join-Path $packagePath "lib\netstandard2.0\QRCoder.dll"

        if (-not (Test-Path $dllPath)) {
            throw "QRCoder DLL not found at $dllPath."
        }

        # Load the assembly
        Write-Verbose "Loading QRCoder assembly from $dllPath..."
        Add-Type -Path $dllPath -ErrorAction Stop

        # Load System.Drawing.Common (Windows-specific)
        Write-Verbose "Loading System.Drawing.Common assembly..."
        Add-Type -AssemblyName System.Drawing.Common -ErrorAction Stop

        Write-Verbose "QRCoder and System.Drawing.Common loaded successfully."
        return $true
    }
    catch {
        Write-Warning "Failed to load QRCoder or System.Drawing.Common: $_"
        return $false
    }
}

function New-QRCode {
    param(
        [string]$Content
    )
    
    # Create a temp file for the QR code
    $tempFile = [System.IO.Path]::GetTempFileName() + ".png"
    
    try {
        # Load QRCoder and System.Drawing.Common
        if (-not (Import-QRCoder -Version "1.6.0" -Verbose)) {
            throw "Failed to load QRCoder library."
        }

        # Generate QR code using QRCoder.QRCode with System.Drawing.Common
        $qrGenerator = New-Object QRCoder.QRCodeGenerator
        $qrCodeData = $qrGenerator.CreateQrCode($Content, [QRCoder.QRCodeGenerator+ECCLevel]::Q)
        $qrCode = New-Object QRCoder.QRCode($qrCodeData)
        $bitmap = $qrCode.GetGraphic(20) # 20 pixels per module

        # Save to file
        $bitmap.Save($tempFile, [System.Drawing.Imaging.ImageFormat]::Png)
        $bitmap.Dispose() # Clean up bitmap resource
        
        # Open the QR code image
        Write-Host "Opening QR Code... Scan this with your device." -ForegroundColor Green
        Invoke-Item $tempFile
        
        return $tempFile
    }
    catch {
        Write-Warning "Failed to generate QR code: $_"
        Write-Warning "Technical details: $($_.Exception.Message)"
        
        # Fallback to displaying the URL
        Write-Host "`nFallback option: Please manually enter this URL in your device:" -ForegroundColor Yellow
        Write-Host $Content -ForegroundColor Cyan
        return $null
    }
}

# Verify executable exists
if (-not (Test-Path $ExecutablePath)) {
    Write-Error "The executable file '$ExecutablePath' was not found. Please provide the correct path."
    exit 1
}

# Handle authentication token
if (-not $AuthToken) {
    $AuthToken = $env:UPLOAD_SERVER_AUTHTOKEN
    
    if (-not $AuthToken) {
        Write-Host "No authentication token provided or found in environment variables." -ForegroundColor Yellow
        $AuthToken = Read-Host "Enter an authentication token" -AsSecureString | ConvertFrom-SecureString -AsPlainText
        
        if (-not $AuthToken) {
            Write-Error "An authentication token is required."
            exit 1
        }
    }
}

# Set environment variable for the process
$env:UPLOAD_SERVER_AUTHTOKEN = $AuthToken

# Prepare arguments for the Go program
$arguments = @()
$arguments += "-dir", "`"$UploadDir`""
$arguments += "-port", $Port
$arguments += "-max-size", ($MaxSizeMB * 1024 * 1024) # Convert MB to bytes

if ($Debug) {
    $arguments += "-debug"
}

# Display startup information
Write-Host "Starting file upload server with the following configuration:" -ForegroundColor Cyan
Write-Host "  Upload directory: $UploadDir"
Write-Host "  Port: $Port"
Write-Host "  Max file size: $MaxSizeMB MB"
Write-Host "  Debug mode: $($Debug -eq $true)"
Write-Host ""

# Generate QR code if requested
if ($GenerateQR) {
    # Determine IP address to use
    if (-not $InternalIP) {
        $InternalIP = Get-LocalIPAddress
        
        if (-not $InternalIP) {
            $InternalIP = Read-Host "Enter your internal IP address for the QR code"
        }
    }
    
    if ($InternalIP) {
        $serverUrl = "http://$InternalIP`:$Port/upload?token=$AuthToken"
        Write-Host "Server URL: $serverUrl" -ForegroundColor Green
        
        $qrCodeFile = New-QRCode -Content $serverUrl
        if ($qrCodeFile) {
            Write-Host "QR code generated and opened. This QR code contains your authentication token!" -ForegroundColor Yellow
            Write-Host "Security Reminder: This QR code grants access to your server. Do not share it publicly." -ForegroundColor Red
        }
    }
    else {
        Write-Warning "Could not generate QR code without an IP address."
    }
}

# Display helpful information
Write-Host "Server will be available at:" -ForegroundColor Green
Write-Host "  http://localhost:$Port/upload?token=$AuthToken" -ForegroundColor Green
Write-Host ""
Write-Host "Press Ctrl+C to stop the server." -ForegroundColor Yellow
Write-Host ""

# Start the process
try {
    $process = Start-Process -FilePath $ExecutablePath -ArgumentList $arguments -NoNewWindow -PassThru
    
    # Wait for the process to exit
    $process.WaitForExit()
}
catch {
    Write-Error "Failed to start the server: $_"
    exit 1
}
finally {
    # Clean up if necessary
    if ($qrCodeFile -and (Test-Path $qrCodeFile)) {
        Remove-Item $qrCodeFile -Force
    }
}