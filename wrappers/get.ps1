# eGet Wrapper
# by github.com/wincmd64

[CmdletBinding()]
param(
    [Parameter(Position=0, ValueFromPipeline=$true)]
    [string]$AppName
)

# check for eGet
if (Test-Path "$PSScriptRoot\eget.exe") { $env:PATH += ";$PSScriptRoot" }
if (-not (Get-Command "eget.exe" -ErrorAction SilentlyContinue)) {
    Write-Warning "eget.exe not found in $PSScriptRoot."
    $choice = Read-Host "Download and extract eget.exe automatically? (Y/N)"
    
    if ($choice -match "y") {
        $zip = "$PSScriptRoot\eget-windows-amd64.zip"
        
        try {
            Write-Host "Downloading..." -ForegroundColor Cyan
            Invoke-WebRequest -Uri "https://github.com/inherelab/eget/releases/latest/download/eget-windows-amd64.zip" -OutFile $zip -UseBasicParsing
            
            Write-Host "Extracting..." -ForegroundColor Cyan
            Expand-Archive -Path $zip -DestinationPath $PSScriptRoot -Force
            Remove-Item -Path $zip -Force

            if (Test-Path "$PSScriptRoot\eget-windows-amd64.exe") {
                Rename-Item -Path "$PSScriptRoot\eget-windows-amd64.exe" -NewName "eget.exe" -Force
            }

            if (Test-Path "$PSScriptRoot\eget.exe") {
                $env:PATH += ";$PSScriptRoot"
                Write-Host "Done." -ForegroundColor Green
            } else {
                throw "eget.exe was not found after extraction."
            }
        }
        catch {
            Write-Error "Failed to download/extract eget.exe: $_"
            if (Test-Path $zip) { Remove-Item -Path $zip -Force }
            return
        }
    } else {
        Write-Host "Exiting script..."
        return
    }
}

# Load applications configuration
$configFile = "$PSScriptRoot\get.config.ps1"
if (-not (Test-Path $configFile -ErrorAction SilentlyContinue)) {
    Write-Warning "Configuration file not found: $configFile"
    sleep 3
    return
}
# Dot-sourcing the config file to load the $Apps array
$Apps = . $configFile

# Scan current directory and detect versions
$GridList = foreach ($app in $Apps) {
    # Special lookup for eget itself via PATH / $PSScriptRoot
    if ($app.ID -eq "eget.exe") {
        $egetCmd = Get-Command "eget.exe" -ErrorAction SilentlyContinue
        $localFile = if ($egetCmd) { Get-Item $egetCmd.Source } else { $null }
    } else {
        $localFile = Get-ChildItem -Path ".\$($app.ID)" -ErrorAction SilentlyContinue | Select-Object -First 1
    }
    
    $versionDisplay = "Not Installed"
    if ($localFile) {
        $rawVersion = $localFile.VersionInfo.FileVersion
        if ($rawVersion) { 
            $versionDisplay = $rawVersion.Trim() 
            if ($versionDisplay -notmatch "^v") { $versionDisplay = "v$versionDisplay" }
        } else {
            $versionDisplay = "Installed (unknown version)"
        }
    }

    [PSCustomObject]@{
        "App"     = $app.Name
        "Source"  = $app.Source
        "Version" = $versionDisplay
    }
}

if ($AppName) {
    # If the app name is passed as an argument, search for it directly; otherwise open Out-GridView
    $Selected = $GridList | Where-Object { $_.App -like "*$AppName*" }
    if (-not $Selected) {
        Write-Warning "App '$AppName' not found in configuration."
        return
    }
} else {
    # Display GUI selection window
    $Selected = $GridList | 
                Select-Object "App", "Source", "Version" | 
                Sort-Object @{Expression="Version"; Descending=$true}, @{Expression="App"; Ascending=$true} | 
                Out-GridView -Title "eGet wrapper - [$PWD]" -OutputMode Multiple
}
if (-not $Selected) { return }

# Process selected applications
foreach ($item in $Selected) {
    $app = $Apps | Where-Object { $_.Name -eq $item.App }
    if (-not $app) { continue }

    if ($item.Version -ne "Not Installed") {
        # UPDATE
        eget.exe query $app.QueryTarget
        
        $choice = Read-Host "Update current $($item.Version) ? (Y/N)"
        if ($choice -notmatch "y") { continue }
    } else {
        # INSTALLS in non-empty directory
        $ignoredItems = @("eget.exe", "get.config.ps1", $MyInvocation.MyCommand.Name)
        $dirtyItems = Get-ChildItem -Path ".\" | Where-Object { $_.Name -notin $ignoredItems }

        if ($dirtyItems) {
            $dirtyChoice = Read-Host "`n Current directory is not empty. Proceed with $($app.Name) anyway? (Y/N)"
            if ($dirtyChoice -notmatch "y") { 
                Write-Host "`n Skipping installation of $($app.Name)..." -ForegroundColor Gray
                continue 
            }
        }
    }
    
    Invoke-Command -ScriptBlock $app.Action
    if ($LastExitCode -eq 0 -and $?) {
        Write-Host "`n Successfully processed: $($app.Name)" -ForegroundColor Green
        sleep 2
    } else {
        Write-Warning "`n Error occurred while processing $($app.Name)."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}
