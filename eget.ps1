# eGet Wrapper
# by github.com/wincmd64

# Supported apps:
# CrystalDiskMark, HTTP Downloader, KeePass, MPC-HC, qBittorrent, Rufus, SystemInformer, Ventoy, Victoria, WinMTR

# check for eGet
if (Test-Path "$PSScriptRoot\eget.exe") { $env:PATH += ";$PSScriptRoot" }
if (-not (Get-Command "eget" -ErrorAction SilentlyContinue)) {
    Write-Warning "eget.exe not found."
    $choice = Read-Host "Open github.com/inherelab/eget page? (Y/N)"
    if ($choice -match "y") { Start-Process "https://github.com/inherelab/eget" }
    Write-Host "Please install eget and re-run the script. Exiting..."
    sleep 1
    return
}

# === APPS ======================================================================
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
        ID          = "HTTP_Downloader.exe"
        Name        = "HTTP Downloader"
        Source      = "GitHub"
        QueryTarget = "erickutcher/httpdownloader"
        Action      = {
            eget dl --extract-all --asset "64,zip,^Link,^DM,^LS" erickutcher/httpdownloader
            Write-Host "Enabling portable mode for HTTP Downloader..." -ForegroundColor Cyan
            New-Item -Path ".\portable" -ItemType File -Force | Out-Null
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
            # 7z.exe/7z.dll requires to unpack qBittorrent.exe
            if (Test-Path "$PSScriptRoot\7z.exe") { $env:PATH += ";$PSScriptRoot" }
            if (-not (Get-Command "7z" -ErrorAction SilentlyContinue)) {
                Write-Warning "7z.exe not found."
                sleep 1
                return
            }
            eget dl --file "qbittorrent.exe" --asset "x64,setup,exe,^asc,^lt20" "sourceforge:qbittorrent/qbittorrent-win32"
            # portable
            if (-not (Test-Path "profile")) { New-Item -ItemType Directory -Name "profile" | Out-Null }
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
    },
    [PSCustomObject]@{
        ID          = "SystemInformer.exe"
        Name        = "SystemInformer"
        Source      = "GitHub"
        QueryTarget = "winsiderss/si-builds"
        Action      = {
            eget dl --file "^x86*,^*.sig" --asset "win64,zip" winsiderss/si-builds

            $settingsFile = ".\SystemInformer.exe.settings.xml"
            if (-not (Test-Path $settingsFile)) {
            Write-Host "Creating SystemInformer.exe.settings.xml..." -ForegroundColor Cyan
            $xmlContent = @'
<settings>
    <setting name="$schema">https://systeminformer.io/settings.schema.json</setting>
</settings>
'@
            $xmlContent | Out-File -FilePath $settingsFile -Encoding utf8 -Force
            }
       }
    },
    [PSCustomObject]@{
        ID          = "mpc-hc64.exe"
        Name        = "MPC-HC"
        Source      = "GitHub"
        QueryTarget = "clsid2/mpc-hc"
        Action      = {
            eget dl --extract-all --asset "x64,zip" clsid2/mpc-hc
            
            $iniFile = ".\mpc-hc64.ini"
            if (-not (Test-Path $iniFile)) {
                Write-Host "Creating mpc-hc64.ini with custom hotkeys and settings..." -ForegroundColor Cyan
                $iniContent = @'
[Commands2]
;- Esc instead of Alt+X
;- Enter instead of Alt+Enter
;- Alt 1..3 è 1..3 vice versa
CommandMod0=816 1 1b "" 5 0 0 0 0 0
CommandMod1=827 11 31 "" 5 0 0 0 0 0
CommandMod2=828 11 32 "" 5 0 0 0 0 0
CommandMod3=829 11 33 "" 5 0 0 0 0 0
CommandMod4=830 1 d "" 5 3 0 3 0 0
CommandMod5=832 1 31 "" 5 0 0 0 0 0
CommandMod6=833 1 32 "" 5 0 0 0 0 0
CommandMod7=834 1 33 "" 5 0 0 0 0 0
[Settings]
UpdaterAutoCheck=0
AllowMultipleInstances=1
AfterPlayback=1
UseSeekPreview=1
AudioRendererType=MPC Audio Renderer
SpeedStep=25
; black theme
ModernThemeMode=0
; files
RememberFilePos=1
RememberPosForLongerThan=2
RecentFilesNumber=5
;Statusbar
ShowFPSInStatusbar=1
[Toolbars\PlayerToolBar]
ButtonSequence=HHDAAAAAIHDAAAAAKHDAAAAAJJDAAAAAOHDAAAAAPHDAAAAAKJDAAAAALHDAAAAACNDAAAAADNDAAAAABLDAAAAANIDAAAAA
ButtonSequenceSize=48
'@
                $iniContent | Out-File -FilePath $iniFile -Encoding utf8 -Force
                }
        }
    },
    [PSCustomObject]@{
        ID          = "Ventoy2Disk.exe"
        Name        = "Ventoy"
        Source      = "GitHub"
        QueryTarget = "ventoy/Ventoy"
        Action      = {
            eget dl --extract-all --strip-components 1 --asset "windows,zip" ventoy/Ventoy
        }
    },
    [PSCustomObject]@{
        ID          = "Victoria.exe"
        Name        = "Victoria"
        Source      = "SourceForge"
        QueryTarget = "sourceforge:victoria-ssd-hdd"
        Action      = {
            eget dl --extract-all --strip-components 1 sourceforge:victoria-ssd-hdd
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
    }
)
# ===============================================================================

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
        eget query $app.QueryTarget
        
        $choice = Read-Host "Update current $($item.Version) ? (Y/N)"
        if ($choice -notmatch "y") { continue }
    }
    
    Invoke-Command -ScriptBlock $app.Action
}
sleep 1