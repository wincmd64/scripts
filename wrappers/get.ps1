# eGet Wrapper
# by github.com/wincmd64

[CmdletBinding()]
param(
    [Parameter(Position=0, ValueFromPipeline=$true)]
    [string]$AppName,

    # Target directory (default: current one). Created if missing.
    [Parameter(Position=1)]
    [string]$Path
)

# Work in the target directory, if given
if ($Path) {
    if (-not (Test-Path -LiteralPath $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
    Set-Location -LiteralPath $Path
}

# check for eGet
if (Test-Path "$PSScriptRoot\eget.exe") { $env:PATH += ";$PSScriptRoot" }
if (-not (Get-Command "eget.exe" -ErrorAction SilentlyContinue)) {
    Write-Warning "eget.exe not found in $PSScriptRoot."
    $choice = Read-Host "Download and extract eget.exe automatically? (Y/N)"
    
    if ($choice -match "y") {
        $zip = "$PSScriptRoot\eget-windows-amd64.zip"
        
        try {
            Write-Host "Downloading..." -ForegroundColor Cyan
            Start-BitsTransfer -Source "https://github.com/inherelab/eget/releases/latest/download/eget-windows-amd64.zip" -Destination $zip -DisplayName "Downloading eget" -ErrorAction Stop
            
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

# Is the current directory empty? Checked ONCE, before any install changes it
$ignoredItems = @("eget.exe", "get.config.ps1", $MyInvocation.MyCommand.Name)
$dirtyAtStart = [bool](Get-ChildItem -Path ".\" | Where-Object { $_.Name -notin $ignoredItems })
$dirtyConfirmed = $false

# Process selected applications
foreach ($item in $Selected) {
    $app = $Apps | Where-Object { $_.Name -eq $item.App }
    if (-not $app) { continue }

    if ($item.Version -ne "Not Installed") {
        # UPDATE
        Write-Host
        eget.exe query $app.QueryTarget
        
        Write-Host "> Update current $($item.Version) ? [Enter=Yes / Esc=Skip / C=Changelog]: " -NoNewline -ForegroundColor Yellow

        $shouldUpdate = $false
        while ($true) {
            $keyInfo = [Console]::ReadKey($true)
            
            if ($keyInfo.Key -eq 'Enter') {
                Write-Host "Yes" -ForegroundColor Green
                $shouldUpdate = $true
                break
            }
            elseif ($keyInfo.Key -eq 'Escape') {
                Write-Host "Skipped" -ForegroundColor Gray
                break
            }
            elseif ($keyInfo.Key -eq [ConsoleKey]::C) {
                Write-Host "Opening Changelog..." -ForegroundColor Cyan
                if ($app.Changelog) {
                    Start-Process $app.Changelog
                } else {
                    Write-Warning "Changelog URL is empty for $($app.Name)."
                }
                # Prompt again after opening URL
                Write-Host "> Update current $($item.Version) ? [Enter=Yes / Esc=Skip / C=Changelog]: " -NoNewline -ForegroundColor Yellow
            }
            else {
                Write-Host "Skipped" -ForegroundColor Gray
                break
            }
        }

        if (-not $shouldUpdate) { continue }

    } else {
        # INSTALLS in non-empty directory: ask until the first confirmation, then stop asking
        if ($dirtyAtStart -and -not $dirtyConfirmed) {
            Write-Host
            Write-Host "> Current directory is not empty. Proceed with $($app.Name)? [Enter=Yes / Esc=Skip]: " -NoNewline -ForegroundColor Yellow

            $shouldProceed = $false
            while ($true) {
                $keyInfo = [Console]::ReadKey($true)
                
                if ($keyInfo.Key -eq 'Enter') {
                    Write-Host "Yes" -ForegroundColor Green
                    $shouldProceed = $true
                    break
                }
                else {
                    Write-Host "Skipped" -ForegroundColor Gray
                    break
                }
            }

            if (-not $shouldProceed) { continue }
            $dirtyConfirmed = $true
        }
    }

    # Action statements run ONE BY ONE. The first statement that calls eget is the
    # MAIN step: it and everything before it (prerequisites) must succeed.
    # Statements after it are best-effort extras: their failures are ignored.
    # They run inline (no function / no output capture) so eget's interactive prompts
    # keep working; a child scope keeps the Action's variables away from this script's.
    $statements = @($app.Action.Ast.EndBlock.Statements | Where-Object { $_ })
    if (-not $statements) {
        Write-Warning "Action is empty for $($app.Name)."
        continue
    }
    # index of the main step (first statement with an eget call; fallback: the first statement)
    $mainIdx = 0
    for ($k = 0; $k -lt $statements.Count; $k++) {
        $hit = $statements[$k].Find({
            $args[0] -is [System.Management.Automation.Language.CommandAst] -and
            $args[0].GetCommandName() -match '^eget(\.exe)?$'
        }, $true)
        if ($hit) { $mainIdx = $k; break }
    }

    while ($true) {
        $state = @{ Ok = $true; Returned = $false }
        & {
            $__i = 0
            foreach ($__st in $statements) {
                $__i++
                $global:LASTEXITCODE = 0
                $__failed = $false
                $__reached = $false
                $__ok = $true
                try {
                    # Dot-sourced, so variables survive between statements of one Action.
                    # The appended tail captures $? and proves the statement ran to its end
                    # (a "return" inside the statement skips the tail).
                    . ([scriptblock]::Create($__st.Extent.Text + "`n`$__ok = `$?; `$__reached = `$true"))
                } catch {
                    Write-Warning $_.Exception.Message
                    $__failed = $true
                }

                # Action ended itself via "return": stop quietly, its own message is already shown
                if (-not $__reached -and -not $__failed) { $state.Returned = $true; break }

                if (-not $__ok -or $LASTEXITCODE -ne 0) { $__failed = $true }
                if ($__failed) {
                    if (($__i - 1) -le $mainIdx) { $state.Ok = $false; break }   # main step or prerequisite failed
                    Write-Host "Optional step failed (ignored)" -ForegroundColor DarkGray
                }
            }
        }

        if ($state.Returned) { break }

        if ($state.Ok) {
            Write-Host "`n Successfully processed: $($app.Name)" -ForegroundColor Green
            break
        }

        Write-Host; Write-Warning "Error occurred while processing $($app.Name)."
        Write-Host "`n> Retry? [Enter=Yes / Esc=Skip]: " -NoNewline -ForegroundColor Yellow

        $retry = $false
        while ($true) {
            $key = [Console]::ReadKey($true).Key
            if ($key -eq 'Enter') { Write-Host "Yes" -ForegroundColor Green; $retry = $true; break }
            if ($key -eq 'Escape') { Write-Host "Skipped" -ForegroundColor Gray; break }
        }

        if (-not $retry) { break }
    }
}

# Exiting: Esc = exit now, any other key = pause (stay open until Esc)
Write-Host `n
$paused = $false
for ($s = 3; $s -gt 0 -and -not $paused; $s--) {
    Write-Host -NoNewline "`r Press Esc to exit, any other key to pause ($s)...   " -BackgroundColor DarkGray
    for ($j = 0; $j -lt 20; $j++) {
        if ([Console]::KeyAvailable) {
            if ([Console]::ReadKey($true).Key -eq 'Escape') { exit }
            $paused = $true
            break
        }
        Start-Sleep -m 50
    }
}
if ($paused) {
    Write-Host -NoNewline "`r Paused. Press Esc to exit...                          " -BackgroundColor DarkGray
    while ([Console]::ReadKey($true).Key -ne 'Escape') { }
}
