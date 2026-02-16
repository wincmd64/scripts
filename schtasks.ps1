# Creates a scheduled task to run an executable with highest privileges at user logon without UAC prompt
# by github.com/wincmd64

param(
    [string]$FilePath,
    [Switch]$Install
)

# --- INSTALL LOGIC ---
if ($Install) {
    $sendToPath = [Environment]::GetFolderPath('SendTo')
    $shortcutPath = Join-Path $sendToPath "Add to schtasks.lnk"
    $wsShell = New-Object -ComObject WScript.Shell
    $shortcut = $wsShell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = "powershell.exe"
    $shortcut.Arguments = "-NoP -EP Bypass -File `"$PSCommandPath`""
    $shortcut.IconLocation = "powershell.exe,1"
    $shortcut.Description = "Create a scheduled task to skip UAC"
    $shortcut.Save()

    # Set 'Run as Administrator' property for the shortcut
    $bytes = [System.IO.File]::ReadAllBytes($shortcutPath)
    $bytes[0x15] = $bytes[0x15] -bor 0x20
    [System.IO.File]::WriteAllBytes($shortcutPath, $bytes)

    Write-Host "SUCCESS: Shortcut created in SendTo menu." -ForegroundColor Green
    Write-Host "Now you can right-click any file -> SendTo -> Add to schtasks."
    pause
    exit
}

# Existing
if (-not $FilePath) { Write-Warning "No file specified! Use -Install to setup."; exit 1}
# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`" -FilePath `"$FilePath`"" -Verb RunAs; exit}
# Verify target file exists
if (-not (Test-Path $FilePath)) {Write-Warning "File not found: $FilePath"; exit 1}
# Verify .ext
$allowedExtensions = @('.exe', '.cmd', '.bat', '.ps1')
$fileExtension = [System.IO.Path]::GetExtension($FilePath)
if ($allowedExtensions -notcontains $fileExtension) {
    Write-Warning "Unsupported file type: $fileExtension. Allowed: $($allowedExtensions -join ', ')"; pause; exit 1
}

# Remove existing task
$taskName = "[hideUAC] " + [System.IO.Path]::GetFileName($FilePath)
schtasks /Delete /TN $taskName /F 2>&1 | Out-Null

# Ask for parameters
$params = Read-Host "Enter parameters (or press Enter for none)"

if ($fileExtension -eq '.ps1') {
    if ($params) {
        $command = "& '$FilePath' $params"
        $bytes = [System.Text.Encoding]::Unicode.GetBytes($command)
        $encodedCommand = [Convert]::ToBase64String($bytes)
        $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoP -WindowStyle Hidden -EP Bypass -EncodedCommand $encodedCommand"
    } else {
        $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoP -WindowStyle Hidden -EP Bypass -File `"$FilePath`""
    }
} else {
    $action = if ($params) {
        New-ScheduledTaskAction -Execute $FilePath -Argument $params
    } else {
        New-ScheduledTaskAction -Execute $FilePath
    }
}

$trigger = New-ScheduledTaskTrigger -AtLogOn
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERNAME" -LogonType Interactive -RunLevel Highest

# Register new task
try {
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Description "Auto-start without UAC prompt" -Force
    Write-Host "`nDONE." -ForegroundColor Green
}
catch {
    Write-Warning "`nERROR: $($_.Exception.Message)"
    exit 1
}

Sleep 1