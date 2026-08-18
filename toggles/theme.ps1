<#
Manages Windows System and App Themes (Light / Dark)

Modes:
  .\theme.ps1                         Displays current status for both System and App themes
  .\theme.ps1 dark | light            Sets both System and App themes to Dark / Light
  .\theme.ps1 -Sys dark               Sets System theme to Dark without changing App theme
  .\theme.ps1 -App light              Sets App theme to Light without changing System theme
  .\theme.ps1 -Sys light -App dark    Sets System theme to Light and App theme to Dark
#>

param(
    # Positional parameter for global mode: dark | light | status
    [Parameter(Position=0)]
    [ValidateSet("light", "dark", "status", "")]
    [string]$Mode,

    # Named parameter for System theme
    [ValidateSet("light", "dark")]
    [string]$Sys,

    # Named parameter for App theme
    [ValidateSet("light", "dark")]
    [string]$App
)

$RegPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"

# If global $Mode is specified (e.g., .\theme.ps1 dark), apply it to both targets
if ($Mode -and $Mode -ne "status") {
    $Sys = $Mode
    $App = $Mode
}

# Update System theme
if ($Sys) {
    $val = if ($Sys -eq "light") { 1 } else { 0 }
    Set-ItemProperty -Path $RegPath -Name "SystemUsesLightTheme" -Value $val -Type Dword -Force
}

# Update App theme
if ($App) {
    $val = if ($App -eq "light") { 1 } else { 0 }
    Set-ItemProperty -Path $RegPath -Name "AppsUseLightTheme" -Value $val -Type Dword -Force
}

# Output current registry status
Get-ItemProperty -Path $RegPath | Select-Object SystemUsesLightTheme, AppsUseLightTheme