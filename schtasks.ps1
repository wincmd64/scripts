# Creates a scheduled task to run an executable with highest privileges at user logon without UAC prompt
# by github.com/wincmd64

param(
    [Parameter(Mandatory=$true)]
    [string]$FilePath
)

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`" -FilePath `"$FilePath`"" -Verb RunAs; exit}
# Verify target file exists
if (-not (Test-Path $FilePath)) {Write-Warning "File not found: $FilePath"; exit 1}

# Remove existing task
$taskName = "[hideUAC] " + [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
schtasks /Delete /TN $taskName /F 2>&1 | Out-Null

# .ps1 exception
if ([System.IO.Path]::GetExtension($FilePath) -eq '.ps1') {
    # Ask for PowerShell script parameters
    $params = Read-Host "Enter parameters for PowerShell script (or press Enter for none)"
    $action = if ($params) {
        New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoP -EP Bypass -File `"$FilePath`" `"$params`""
    } else {
        New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoP -EP Bypass -File `"$FilePath`""
    }
} else {
    $action = New-ScheduledTaskAction -Execute $FilePath
}

$trigger = New-ScheduledTaskTrigger -AtLogOn
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERNAME" -LogonType Interactive -RunLevel Highest

# Register new task
try {
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Description "Auto-start without UAC prompt" -Force
    Write-Host "`nDONE." -ForegroundColor Green
}
catch {
    Write-Warning "`nERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
Sleep 1
