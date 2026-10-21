# UWP apps uninstaller

$app2delete = @(
     # Get list of installed apps: Get-AppxPackage | Select Name, PackageFullName
    "Microsoft.Windows.DevHome",
    "Microsoft.WindowsFeedbackHub",
    "Microsoft.MicrosoftOfficeHub",          # MS 365 Copilot
    "Clipchamp.Clipchamp",
    "Microsoft.MicrosoftStickyNotes",
    "Microsoft.BingWeather",
    "Microsoft.BingNews",
    "Microsoft.OutlookForWindows",
    "Microsoft.PowerAutomateDesktop",
    "Microsoft.MicrosoftSolitaireCollection",
    "Microsoft.GamingApp",                   # Xbox
    "Microsoft.YourPhone",
    "Microsoft.GetHelp",
    "A025C540.Yandex.Music",
    "Microsoft.XboxSpeechToTextOverlay",
    "Microsoft.BingSearch",
    "Microsoft.Edge.GameAssist",
    "Microsoft.XboxIdentityProvider",
    "Microsoft.Xbox.TCUI"
)

# Removable apps of the current user; apps from $app2delete go first and are marked "preset"
$installed = Get-AppxPackage |
    Where-Object { -not $_.IsFramework -and -not $_.NonRemovable } |
    Select-Object Name, Version,
        @{ n = "Preset"; e = { if ($app2delete -contains $_.Name) { "preset" } } },
        PackageFullName |
    Sort-Object @{ e = { $_.Preset -ne "preset" } }, Name

$selected = $installed | Out-GridView -Title "Select apps to remove (tip: type 'preset' in the filter, Ctrl+A, OK)" -PassThru
if (-not $selected) { return } # Window closed or Cancel pressed

foreach ($app in $selected) {
    try {
        Remove-AppxPackage $app.PackageFullName -ErrorAction Stop
        Write-Output "$($app.Name) - deleted"
    } catch {
        Write-Warning "$($app.Name) - error deleting"
    }
}
pause