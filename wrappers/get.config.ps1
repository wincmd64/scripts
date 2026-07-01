# eGet Wrapper - Apps configuration
# by github.com/wincmd64

#   [Supported apps]
# CrystalDiskMark, fastfetch, FFmpeg, HTTP Downloader,
# KeePass, LAV Filters, MPC-HC, qBittorrent, Rufus,
# SystemInformer, Ventoy, Victoria, WinDirStat, WinMTR, UniExtract2

$Apps = @(
    [PSCustomObject]@{
        ID          = "DiskMark64.exe"
        Name        = "CrystalDiskMark"
        Source      = "SourceForge"
        QueryTarget = "sourceforge:crystaldiskmark"
        Action      = {
            eget.exe dl --file "DiskMark64.exe,CdmResource" --asset "zip,^Shizuku,^Aoi,^Src" "sourceforge:crystaldiskmark"
        }
    },
    [PSCustomObject]@{
        ID          = "HTTP_Downloader.exe"
        Name        = "HTTP Downloader"
        Source      = "GitHub"
        QueryTarget = "erickutcher/httpdownloader"
        Action      = {
            eget.exe dl --extract-all --asset "64,zip,^Link,^DM,^LS" erickutcher/httpdownloader
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
            eget.exe dl --extract-all --asset "zip,^REG:Source" "sourceforge:keepass/KeePass 2.x"
            eget.exe dl --fallback-versions 5 --asset "Ukrainian,zip" --extract-all --to .\Languages "sourceforge:keepass/Translations 2.x"
            eget.exe dl --fallback-versions 2 --asset "Russian,zip" --extract-all --to .\Languages "sourceforge:keepass/Translations 2.x"
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
            eget.exe dl --file "qbittorrent.exe" --asset "x64,setup,exe,^asc,^lt20" "sourceforge:qbittorrent/qbittorrent-win32"
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
            eget.exe dl --asset "p.exe" pbatard/rufus
        }
    },
    [PSCustomObject]@{
        ID          = "SystemInformer.exe"
        Name        = "SystemInformer"
        Source      = "GitHub"
        QueryTarget = "winsiderss/si-builds"
        Action      = {
            eget.exe dl --file "^x86*,^*.sig" --asset "win64,zip" winsiderss/si-builds

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
        ID          = "Ventoy2Disk.exe"
        Name        = "Ventoy"
        Source      = "GitHub"
        QueryTarget = "ventoy/Ventoy"
        Action      = {
            eget.exe dl --extract-all --strip-components 1 --asset "windows,zip" ventoy/Ventoy
        }
    },
    [PSCustomObject]@{
        ID          = "Victoria.exe"
        Name        = "Victoria"
        Source      = "SourceForge"
        QueryTarget = "sourceforge:victoria-ssd-hdd"
        Action      = {
            eget.exe dl --extract-all --strip-components 1 sourceforge:victoria-ssd-hdd
        }
    },
    [PSCustomObject]@{
        ID          = "WinMTR.exe"
        Name        = "WinMTR"
        Source      = "GitHub"
        QueryTarget = "leeter/WinMTR-refresh"
        Action      = {
            eget.exe dl --extract-all --asset "x64,zip" leeter/WinMTR-refresh
        }
    },
    [PSCustomObject]@{
        ID          = "UniExtract.exe"
        Name        = "Universal Extractor"
        Source      = "GitHub"
        QueryTarget = "gvp9000/UniExtract2"
        Action      = {
            eget.exe dl --extract-all --strip-components 1 --asset "zip" gvp9000/UniExtract2
        }
    },
    [PSCustomObject]@{
        ID          = "LAVAudio.ax"
        Name        = "LAV Filters"
        Source      = "GitHub"
        QueryTarget = "Nevcairiel/LAVFilters"
        Action      = {
            eget.exe dl --file "*.ax,*.dll,*.manifest" --asset "x64,zip" Nevcairiel/LAVFilters
        }
    },
    [PSCustomObject]@{
        ID          = "ffmpeg.exe"
        Name        = "FFmpeg"
        Source      = "GitHub"
        QueryTarget = "GyanD/codexffmpeg"
        Action      = {
            eget.exe dl --file "*.exe" --strip-components 2 --asset "essentials,zip" GyanD/codexffmpeg
        }
    },
    [PSCustomObject]@{
        ID          = "WinDirStat.exe"
        Name        = "WinDirStat"
        Source      = "GitHub"
        QueryTarget = "windirstat/windirstat"
        Action      = {
            eget.exe dl --asset "zip" --file "x64/*.exe" --strip-components 1 windirstat/windirstat
            
            $iniFile = ".\WinDirStat.ini"
            if (-not (Test-Path $iniFile)) {
                Write-Host "Creating WinDirStat.ini..." -ForegroundColor Cyan
                $iniContent = @'
[Options]
ShowElevationPrompt=0
[TreeMapView]
ShowTreeMap=0
'@
                $iniContent | Out-File -FilePath $iniFile
                }
        }
    },
    [PSCustomObject]@{
        ID          = "mpc-hc64.exe"
        Name        = "MPC-HC"
        Source      = "GitHub"
        QueryTarget = "clsid2/mpc-hc"
        Action      = {
            eget.exe dl --extract-all --asset "x64,zip" clsid2/mpc-hc
            
            $iniFile = ".\mpc-hc64.ini"
            if (-not (Test-Path $iniFile)) {
                Write-Host "Creating mpc-hc64.ini..." -ForegroundColor Cyan
                $iniContent = @'
[Commands2]
;- Esc instead of Alt+X
;- Enter instead of Alt+Enter
;- Alt 1..3 - 1..3 vice versa
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
        ID          = "fastfetch.exe"
        Name        = "fastfetch CLI"
        Source      = "GitHub"
        QueryTarget = "fastfetch-cli/fastfetch"
        Action      = {
            eget.exe dl --file "fastfetch.exe" --asset "windows,amd64,7z" fastfetch-cli/fastfetch
            
            $jsonFile = ".\fastfetch.jsonc"
            if (-not (Test-Path $jsonFile)) {
                Write-Host "Creating fastfetch.jsonc with custom configuration..." -ForegroundColor Cyan
                $jsonContent = @'
{
    "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
    "logo": {
        "source": "windows"
    },
    "modules": [
        {
            "type": "version",
            "key": "fastfetch",
            "keyColor": "red",
            "format": "{version}"
        },
        {
            "type": "title",
            "key": "Host",
            "format": "{2}, {1}",
            "keyColor": "green"
        },
        {
            "type": "os",
            "keyColor": "green"
        },
        {
            "type": "uptime",
            "keyColor": "green"
        },
        {
            "type": "disk",
            "folders": "/",
            "keyColor": "green"
        },
        {
            "type": "bios",
            "key": "BIOS",
            "format": "{type}, {vendor}"
        },
        "TPM",
        "CPU",
        "GPU",
        "PhysicalMemory",
        {
            "type": "PhysicalDisk",
            "temp": true
        },
        {
            "type": "BluetoothRadio",
            "keyColor": "cyan"
        },
        {
            "type": "Bluetooth",
            "keyColor": "cyan"
        },
        {
            "type": "Display",
            "keyColor": "cyan"
        },
        {
            "type": "Wifi",
            "keyColor": "yellow"
        },
        {
            "type": "LocalIp",
            "keyColor": "yellow"
        },
        {
            "type": "dns",
            "keyColor": "yellow"
        },
        {
            "type": "PublicIp",
            "keyColor": "yellow"
        }
    ]
}
'@
                $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
                [System.IO.File]::WriteAllText((Resolve-Path .).Path + "\fastfetch.jsonc", $jsonContent, $utf8NoBom)
            }
        }
    }
)

# Return the array to the calling script
$Apps