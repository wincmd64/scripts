<#
    Wrapper for SDelete - secure delete utility
    
    [USAGE]
    TotalCmd button:  powershell -NoP -EP Bypass -File sdelete_Q.ps1 -List %UL %Y
                      (%Y = empty list when nothing is selected, so the free space mode is offered)
    SendTo shortcut:  run once: powershell -NoP -EP Bypass -File sdelete_Q.ps1 -Shortcut
    No selection:     offers to zero free space of a drive
    
    [COMMAND LINE ARGUMENTS]
    -List <file>  - UTF-8 list file, one path per line (no command line length limit)
    -Shortcut     - create shortcut in Shell:SendTo folder
 #>   


# PositionalBinding off: otherwise the first SendTo file would be bound to -List
# param must be the first statement in the script
[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$List,                                          # list file from TotalCmd (%UL)
    [switch]$Shortcut,                                      # create SendTo shortcut and exit
    [Parameter(ValueFromRemainingArguments)][string[]]$Path # or paths passed directly (SendTo)
)

# any error before sdelete is called must stop the script, never continue to deletion
$ErrorActionPreference = 'Stop'

# ______________________SETTINGS______________________
$app       = ''    # full path to sdelete exe, empty = next to this script (sdelete64.exe on x64, sdelete.exe on x86)
$logFile   = Join-Path $env:TEMP 'sdelete.log'
$maxShown  = 5
# protected paths: skipped together with everything inside; FULL paths only, wildcards * ? allowed
$protected = @($env:SystemRoot, $env:ProgramFiles, ${env:ProgramFiles(x86)}) | Where-Object { $_ }
# ____________________________________________________

# the OS bitness decides, not the process one: a 32-bit PowerShell on x64 Windows still gets sdelete64.exe
$exe = if ([Environment]::Is64BitOperatingSystem) { 'sdelete64.exe' } else { 'sdelete.exe' }
if (-not $app) { $app = Join-Path $PSScriptRoot $exe }
$files = 0; $dirs = 0; $notFound = 0; $failed = 0

# functions must be defined before they are called
function Test-Protected($p) {
    $p = $p.TrimEnd('\')
    foreach ($d in $protected) {
        $d = $d.TrimEnd('\')
        if ($p -like $d -or $p -like "$d\*") { return $true }                                  # the item itself or inside it
        if ($d.StartsWith($p + '\', [StringComparison]::OrdinalIgnoreCase)) { return $true }  # a parent of a protected path (e.g. C:\)
    }
    return $false
}

# one-line status: carriage return + padding, cut to the console width
function Show-Status($text) {
    $w = [Math]::Max(20, [Console]::WindowWidth - 1)
    if ($text.Length -gt $w) { $text = $text.Substring(0, $w - 3) + '...' }
    Write-Host ("`r" + $text.PadRight($w)) -NoNewline
}

function Start-Log {
    $script:log = [IO.StreamWriter]::new($logFile, $false, (New-Object Text.UTF8Encoding $true))   # BOM: Notepad reads it as UTF-8
    $log.AutoFlush = $true
    $log.WriteLine('SDelete run: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
    $script:total = [Diagnostics.Stopwatch]::StartNew()
}

# runs sdelete, writes its output to the log, shows only the last line in the console
function Invoke-SDelete($prefix, [string[]]$sdArgs) {
    $eap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'   # with 'Stop', stderr of a native command throws on 2>&1 in Windows PowerShell 5.1
    # sdelete writes UTF-16 to a pipe: decode it as such, otherwise every character is followed by a NUL
    $enc = [Console]::OutputEncoding
    try { [Console]::OutputEncoding = [Text.Encoding]::Unicode } catch { }
    $sw = [Diagnostics.Stopwatch]::StartNew()
    & $app -nobanner -accepteula @sdArgs 2>&1 | ForEach-Object {
        $line = ("$_" -replace "`0", '').TrimEnd()   # also strip leftover NULs in case the encoding switch failed
        if (-not $line) { return }                   # sdelete prints a lot of empty lines, keep them out of the log
        $log.WriteLine($line)
        if ($line -match '^Files deleted:\s*(\d+)')       { $script:files += [int]$Matches[1] }
        if ($line -match '^Directories deleted:\s*(\d+)') { $script:dirs  += [int]$Matches[1] }
        if ($line -match 'No files/folders found')        { $script:notFound++ }
        if ($sw.ElapsedMilliseconds -gt 100) { Show-Status "$prefix $line"; $sw.Restart() }
    }
    $code = $LASTEXITCODE
    try { [Console]::OutputEncoding = $enc } catch { }
    if ($code -ne 0) { $script:failed++; $log.WriteLine("exit code: $code") }
    $ErrorActionPreference = $eap
}

function Complete-Run($n) {
    Write-Host ("`r" + ' ' * ([Console]::WindowWidth - 1) + "`r") -NoNewline
    $sum = "Objects: $n"
    if ($files + $dirs) { $sum += "   Files deleted: $files   Dirs deleted: $dirs" }
    if ($notFound)      { $sum += "   Not found: $notFound" }
    if ($failed)        { $sum += "   Failed: $failed" }
    $sum += '   Time: ' + $total.Elapsed.ToString('hh\:mm\:ss')
    $log.WriteLine("`n$sum"); $log.Close()
    Write-Host `n'DONE.'
    Write-Host $sum
    Write-Host `n"Log: $logFile`nPress O to open it, any other key to close"
    if ([Console]::ReadKey($true).Key -eq 'O') { Invoke-Item $logFile }
}

# numbered list of ready fixed/removable drives with free space
function Select-Drive {
    $drives = @([IO.DriveInfo]::GetDrives() | Where-Object { $_.IsReady -and $_.DriveType.ToString() -in 'Fixed', 'Removable' })
    Write-Host `n'Zero free drive space' -BackgroundColor Red
    for ($i = 0; $i -lt $drives.Count; $i++) {
        $d = $drives[$i]
        Write-Host ('  {0}) {1}  {2,-16} {3,8:N1} GB free of {4:N1} GB' -f ($i + 1), $d.Name, $d.VolumeLabel, ($d.AvailableFreeSpace / 1GB), ($d.TotalSize / 1GB))
    }
    $a = Read-Host `n'> Enter number or drive letter (Enter = cancel)'
    if ($a -match '^\d+$' -and [int]$a -ge 1 -and [int]$a -le $drives.Count) { return $drives[[int]$a - 1].Name.Substring(0, 2) }
    if ($a -match '^[a-zA-Z]:?$') { $x = $a.Substring(0, 1).ToUpper() + ':'; if ($drives.Name -contains "$x\") { return $x } }
    return ''
}

# /shortcut: create shortcut in Shell:SendTo folder
if ($Shortcut) {
    $s = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path ([Environment]::GetFolderPath('SendTo')) 'Secure Delete.lnk'))
    $s.TargetPath = (Get-Process -Id $PID).Path   # the PowerShell that runs this script
    $s.Arguments  = "-NoP -EP Bypass -File `"$PSCommandPath`""
    $s.IconLocation = 'imageres.dll,-5320'
    $s.Save()
    Write-Host `n"Shortcut 'Secure Delete.lnk' created."; sleep 2; exit
}

# sdelete exe not found: offer to download it next to the script
if (-not (Test-Path -LiteralPath $app)) {
    $answer = Read-Host `n"$exe not found. Download to '$(Split-Path $app)'? [Y/N]"
    if ($answer -notmatch '^[yY]') { exit 1 }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12   # Windows PowerShell 5.1 defaults to older TLS
    $ProgressPreference = 'SilentlyContinue'                                          # the progress bar makes Invoke-WebRequest very slow in 5.1
    for ($try = 1; $try -le 3 -and -not (Test-Path -LiteralPath $app); $try++) {
        try { Invoke-WebRequest "https://live.sysinternals.com/$exe" -OutFile $app -UseBasicParsing }
        catch { Write-Host `n"Download failed: $($_.Exception.Message)" -ForegroundColor Yellow; sleep 5 }
    }
    if (-not (Test-Path -LiteralPath $app)) { Read-Host `n'Download failed. Press Enter'; exit 1 }
}

# list file: -Encoding UTF8 strips the BOM itself
if ($List) { $Path = Get-Content -LiteralPath $List -Encoding UTF8 }

# split into allowed / protected
$todo    = @()
$skipped = @()
foreach ($p in $Path) {
    if ([string]::IsNullOrWhiteSpace($p)) { continue }
    if (Test-Protected $p) { $skipped += $p } else { $todo += $p }
}

Clear-Host

# nothing selected at all: zero free space of a drive
if ($todo.Count -eq 0 -and $skipped.Count -eq 0) {
    $drive = Select-Drive
    if (-not $drive) { Write-Host `n'Operation cancelled.' -ForegroundColor Yellow; sleep 1; exit }
    $free = ([IO.DriveInfo]$drive).AvailableFreeSpace / 1GB
    $answer = Read-Host ("`n> WARNING: This will zero the free space on {0} ({1:N1} GB free) and can take a long time. Continue? [Y/N]" -f $drive, $free)
    if ($answer -notmatch '^[yY]') { Write-Host `n'Operation cancelled.' -ForegroundColor Yellow; sleep 1; exit }
    Start-Log
    Invoke-SDelete "Zeroing ${drive}" @('-z', $drive)
    Complete-Run 1
    exit
}

# protected items are never in $todo, so they can't hide under "more"; they get their own short list
if ($skipped.Count) {
    Write-Host `n'Skipped (protected):' -BackgroundColor Yellow -ForegroundColor Black
    $skipped | Select-Object -First $maxShown | ForEach-Object { Write-Host "   $_" }
    if ($skipped.Count -gt $maxShown) { Write-Host ('  ... and {0} more' -f ($skipped.Count - $maxShown)) -ForegroundColor Yellow }
}

if ($todo.Count -eq 0) { Read-Host `n'Nothing to delete, everything selected is protected. Press Enter'; exit }

# preview: first N items, then "... and X more"
Write-Host `n'Selected for secure deletion:' -BackgroundColor Red
$todo | Select-Object -First $maxShown | ForEach-Object { Write-Host "   $_" }
if ($todo.Count -gt $maxShown) { Write-Host ('  ... and {0} more' -f ($todo.Count - $maxShown)) -ForegroundColor Red }

# confirm
$answer = Read-Host `n'> WARNING: This will permanently erase the selected object(s). Continue? [Y/N]'
if ($answer -notmatch '^[yY]') { Write-Host `n'Operation cancelled.' -ForegroundColor Yellow; sleep 1; exit }
Write-Host

# delete
Start-Log
if ($skipped.Count) { $log.WriteLine("`nSkipped (protected):"); $skipped | ForEach-Object { $log.WriteLine("  $_") } }
$i = 0
foreach ($p in $todo) {
    $i++; $prefix = "[$i/$($todo.Count)]"
    # TC gives folders as "dir\": sdelete may take that as a mask for the folder CONTENTS (nothing found for an empty folder);
    # pass the path without the trailing backslash (but keep "C:\")
    $target = if ($p.Length -gt 3) { $p.TrimEnd('\') } else { $p }
    $log.WriteLine("`n=== $prefix sdelete -s `"$target`" ===")
    Show-Status "$prefix $p"
    Invoke-SDelete $prefix @('-s', $target)
}
Complete-Run $todo.Count
