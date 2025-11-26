# BulkSteamValidator
PowerShell based script that enables bulk validation of Steam games

---

## Current Version
**v1.0.0**  
*Initial Release*

---

## Features
- Automatically reads Steam library paths from `libraryfolders.vdf`
- Detects installed games using `.acf` manifest files
- Extracts AppIDs and install folder names
- Validates each game using the Steam client (`steam://validate/<AppID>`)
- Reliable wait mechanism (process-delta monitoring)

---

## Requirements
- Windows 10 or later  
- PowerShell 5.1 or PowerShell 7+  
- Steam client installed  
- Logged-in Steam session

---

## Installation
1. Download or copy `BulkSteamValidator.ps1` to any folder. You will need to have read/write privileges in the folder you place the script. 
2. Ensure Steam is installed and currently logged in.

---

## Usage

### Run the Script
Open PowerShell in the script directory and run:

```powershell
.\BulkSteamValidator.ps1
```
Or specify the Steam install directory if it is not in the default location
```powershell
.\BulkSteamValidator.ps1 -steamDir D:\Steam
