# CHECK FOR EGET
if (Test-Path ".\eget.exe") { $env:PATH += ";$PWD" }
if (-not (Get-Command "eget" -ErrorAction SilentlyContinue)) {
    Write-Warning "eget.exe was not found in PATH or the current directory."
    $choice = Read-Host "Open github.com/inherelab/eget page? (Y/N)"
    if ($choice -match "y") { Start-Process "https://github.com/inherelab/eget" }
    Write-Host "Please install eget and re-run the script. Exiting..."
    return
}

# Apps installation logic 
$Apps = @(
    [PSCustomObject]@{
        ID          = "DiskMark64.exe"
        Name        = "CrystalDiskMark"
        Source      = "SourceForge"
        QueryTarget = "sourceforge:crystaldiskmark"
        Action      = {
            eget dl --file "DiskMark64.exe,CdmResource" --asset "zip,^Shizuku,^Aoi,^Src" "sourceforge:crystaldiskmark"
        }
    },
    [PSCustomObject]@{
        ID          = "KeePass.exe"
        Name        = "KeePass"
        Source      = "SourceForge"
        QueryTarget = "sourceforge:keepass/KeePass 2.x"
        Action      = {
            eget dl --extract-all --asset "zip,^REG:Source" "sourceforge:keepass/KeePass 2.x"
            eget dl --fallback-versions 5 --asset "Ukrainian,zip" --extract-all --to .\Languages "sourceforge:keepass/Translations 2.x"
            eget dl --fallback-versions 2 --asset "Russian,zip" --extract-all --to .\Languages "sourceforge:keepass/Translations 2.x"
        }
    },
    [PSCustomObject]@{
        ID          = "qbittorrent.exe"
        Name        = "qBittorrent"
        Source      = "SourceForge"
        QueryTarget = "sourceforge:qbittorrent/qbittorrent-win32"
        Action      = {
            # Note: Requires 7z.exe/7z.dll in PATH for eget to unpack qBittorrent setup.exe
            eget dl --file "qbittorrent.exe" --asset "x64,setup,exe,^asc,^lt20" "sourceforge:qbittorrent/qbittorrent-win32"
            if (-not (Test-Path "profile")) { New-Item -ItemType Directory -Name "profile" | Out-Null }
        }
    },
    [PSCustomObject]@{
        ID          = "WinMTR.exe"
        Name        = "WinMTR"
        Source      = "GitHub"
        QueryTarget = "leeter/WinMTR-refresh"
        Action      = {
            eget dl --extract-all --asset "x64,zip" leeter/WinMTR-refresh
        }
    },
    [PSCustomObject]@{
        ID          = "Ventoy2Disk.exe"
        Name        = "Ventoy"
        Source      = "GitHub"
        QueryTarget = "ventoy/Ventoy"
        Action      = {
            eget dl --extract-all --asset "windows,zip" ventoy/Ventoy
        }
    },
    [PSCustomObject]@{
        ID          = "*rufus*.exe"
        Name        = "Rufus"
        Source      = "GitHub"
        QueryTarget = "pbatard/rufus"
        Action      = {
            eget dl --asset "p.exe" pbatard/rufus
        }
    }
)

# Scan current directory and detect versions
$GridList = foreach ($app in $Apps) {
    $localFile = Get-ChildItem -Path ".\$($app.ID)" -ErrorAction SilentlyContinue | Select-Object -First 1
    
    $versionDisplay = "Not Installed"
    if ($localFile) {
        $rawVersion = $localFile.VersionInfo.ProductVersion
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
            Sort-Object "Version" -Descending | 
            Out-GridView -Title "DirGet by github.com/wincmd64" -OutputMode Multiple

if (-not $Selected) { return }

# Process selected applications
foreach ($item in $Selected) {
    $app = $Apps | Where-Object { $_.Name -eq $item.App }
    if (-not $app) { continue }

    # eget query
    if ($item.Version -ne "Not Installed") {
        eget query $app.QueryTarget
        
        $choice = Read-Host "Update current $($item.Version) ? (Y/N)"
        if ($choice -notmatch "y") { continue }
    }
    
    Invoke-Command -ScriptBlock $app.Action
}
