# eGet Wrapper
# by github.com/wincmd64

# check for eGet
if (Test-Path "$PSScriptRoot\eget.exe") { $env:PATH += ";$PSScriptRoot" }
if (-not (Get-Command "eget.exe" -ErrorAction SilentlyContinue)) {
    Write-Warning "eget.exe not found."
    $choice = Read-Host "Open github.com/inherelab/eget page? (Y/N)"
    if ($choice -match "y") { Start-Process "https://github.com/inherelab/eget" }
    Write-Host "Please install eget and re-run the script. Exiting..."
    sleep 1
    return
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
    $localFile = Get-ChildItem -Path ".\$($app.ID)" -ErrorAction SilentlyContinue | Select-Object -First 1
    
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

# Display GUI selection window
$Selected = $GridList | 
            Select-Object "App", "Source", "Version" | 
            Sort-Object @{Expression="Version"; Descending=$true}, @{Expression="App"; Ascending=$true} | 
            Out-GridView -Title "eGet wrapper - by github.com/wincmd64" -OutputMode Multiple

if (-not $Selected) { return }

# Process selected applications
foreach ($item in $Selected) {
    $app = $Apps | Where-Object { $_.Name -eq $item.App }
    if (-not $app) { continue }

    # eget query
    if ($item.Version -ne "Not Installed") {
        eget.exe query $app.QueryTarget
        
        $choice = Read-Host "Update current $($item.Version) ? (Y/N)"
        if ($choice -notmatch "y") { continue }
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
