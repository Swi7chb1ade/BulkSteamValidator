<#
.SYNOPSIS
    Bulk Steam Game Validator
.DESCRIPTION
    Allows the bulk validation of all installed Steam games
.NOTES
    Last edited: 2025-11-27
    Author: Swi7chblade
    Version: 1.0.0
#>

# Script paramaters
param(
    $steamDir = "C:\Program Files (x86)\Steam"
)

# Script Variables
$libraryVdfFile = "$steamDir\steamapps\libraryfolders.vdf" # Steam library folder file
$steamIdleThreshold = 5 # seconds of low activity before assuming done
$validationTimeoutThreshold = 30 # Maximum allowed time per AppID validation (in minutes)
$validatedIdsLog = "$PSScriptRoot\validatedIDs.txt" # List of AppIDs already validated
$blacklistedAppidsFile = "$PSScriptRoot\validationBlacklist.txt" # List of AppIDs that are blacklisted from validation

# Helper function to capture steam.exe process stats
function Get-SteamStats{
    $procs = Get-Process -Name "Steam","SteamService" -ErrorAction SilentlyContinue
    if (-not $procs) { return $null }
    $cpu  = ($procs | Measure-Object -Property CPU -Sum).Sum
    $handles = ($procs | Measure-Object -Property HandleCount -Sum).Sum
    return [PSCustomObject]@{ CPU = $cpu; Handles = $handles }
}

# Helper function to get Steam library paths from the libraryfolders.vdf file clean double backslashes
function Get-SteamLibraryPaths {
    param([string]$libraryVdfFile)

    $paths = @()
    foreach ($line in (Get-Content $libraryVdfFile)) {
        if ($line -like '*"path"*') {
            $parts = $line -split '"'
            if ($parts.Count -ge 4) {
                $paths += ($parts[3] -replace '\\\\','\')
            }
        }
    }
    return $paths
}

# Clear console to make things tidy
Clear-Host

# If Steam.exe is not found in the default location, prompt the user to enter the directory:
if(!(Test-Path "$steamDir\Steam.exe")){

    do{
        Write-Host -ForegroundColor Gray "================================================================="
        Write-Host -ForegroundColor Yellow "Steam.exe not found - please specify the directory that Steam.exe is located in"
        $steamDir = Read-Host  "Enter Steam.exe directory (Eg: 'D:\Steam')" 
        $libraryVdfFile = "$steamDir\steamapps\libraryfolders.vdf" # Steam library folder file
    }

    while(!(Test-Path "$steamDir\Steam.exe"))
}
else{
    Write-Host -ForegroundColor Gray "================================================================="
    Write-Host -ForegroundColor Green "Steam.exe found in default location"
}

# 
$libraryPaths = Get-SteamLibraryPaths $libraryVdfFile
Write-Host -ForegroundColor Gray "================================================================="
Write-Host -ForegroundColor Green "Discovered Steam library folders:"
$libraryPaths | Write-Host -ForegroundColor Cyan

# Import already validated App IDs
Write-Host -ForegroundColor Gray "================================================================="
if(Test-Path $validatedIdsLog){
    Write-Host -ForegroundColor Green "List of previously validated Steam AppIDs exists - importing"
    $validatedIds = Get-Content $validatedIdsLog
    Write-Host -ForegroundColor Green "List of previously validated Steam AppIDs"
    $validatedIds | Write-Host -ForegroundColor Cyan
}

else{
    Write-Host "Validation log does not exist - creating"
    New-Item -Path "$PSScriptRoot\validatedIDs.txt" -ItemType File
}

# Import blacklisted App IDs
if(Test-Path $blacklistedAppidsFile){
    Write-Host -ForegroundColor Gray "================================================================="
    Write-Host -ForegroundColor Green "Steam AppID blacklist file exists - importing"
    $blacklistedIds = Get-Content $blacklistedAppidsFile
    Write-Host -ForegroundColor Green "List of blacklisted Steam AppIDs"
    $blacklistedIds | Write-Host -ForegroundColor Yellow
}

# Loop through each library folder
foreach($libraryPath in $libraryPaths){
    # Get all the ACF files from the path
    $acfFiles = Get-ChildItem -Path "$libraryPath\steamapps" -Filter "*.acf"

    # Loop through each acf file
    foreach ($acf in $acfFiles){
        # Write progress to console
        Write-Host -ForegroundColor Gray "================================================================="
        Write-Host -ForegroundColor Green "Processing $($acf.Name)..."

        # Get the ACF file content
        $content = Get-Content $acf.FullName

        # Filter to find the Steam appid
        $appid = ($content | Select-String '"appid"' | ForEach-Object { ($_ -split '"')[3] }) | Select-Object -First 1
        $appName = ($content | Select-String '"name"' | ForEach-Object { ($_ -split '"')[3] }) | Select-Object -First 1
        
	    # If the appid has already been validated, skip
        if($appid -in $validatedIds){
            Write-Host -ForegroundColor Blue "Steam AppID $appid already validated - skipping"
            Start-Sleep -Seconds 1
        }

        elseif($appId -in $blacklistedIds){
            Write-Host -ForegroundColor Yellow "Steam AppID $appid is blacklisted from validation - skipping"
            Start-Sleep -Seconds 1
        }
        
	    else{
            # If the appid has not already been validated, validate
            Write-Host "Validating $appName / $appid"
            
            # Use the appid to start a validation task
            Start-Process "steam://validate/$appid"
            
            # Add app ID to $validatedIds
            $appId | Out-File $validatedIdsLog -Append -Encoding utf8 -NoClobber
            
            # Sleep to allow validation to kick in
            Start-Sleep -Seconds 5

            # Initialise monitor stats
            $lastStats = Get-SteamStats
            $lastChange = Get-Date
            $startTime = Get-Date
            
            # Monitor loop
            while ($true){
                Start-Sleep -Seconds 5
                $stats = Get-SteamStats
                if (-not $stats) {
                    Write-Host -ForegroundColor Red "Steam process exited - assuming something went wrong"
                    Exit 1
                }

                # Track how much CPU/handle activity changed
                $cpuDelta  = [math]::Abs($stats.CPU - $lastStats.CPU)
                $hdlDelta  = [math]::Abs($stats.Handles - $lastStats.Handles)
                $totalDelta = $cpuDelta + $hdlDelta
                if($totalDelta -gt 0.01) {
                    $lastChange = Get-Date
                }

                # Action for when Steam is idle for $idleThreshholdSeconds
                $idleTime = (New-TimeSpan -Start $lastChange -End (Get-Date)).TotalSeconds
                $elapsed  = (New-TimeSpan -Start $startTime  -End (Get-Date)).TotalMinutes
                if($idleTime -ge $steamIdleThreshold) {
                    Write-Host -ForegroundColor Green "Steam idle for $idleTime seconds - validation complete"
                    break
                }
                
                # Action when timeout is reached
                if($elapsed -ge $validationTimeoutThreshold) {
                    Write-Host -ForegroundColor Yellow "Timeout after $validationTimeoutThreshold minutes - moving on"
                    break
                }
                
                $lastStats = $stats
            }
        }
    }
}