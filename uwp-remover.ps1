# Uninstall some built-in UWP apps. Tested on Win 11 25H2

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

foreach ($app in $app2delete) {
    try {
        $package = Get-AppxPackage $app -ErrorAction Stop
        if ($package) {
            Remove-AppxPackage $package -ErrorAction Stop
            Write-Output "$app - deleted"
        } else {
            Write-Warning "$app - not found"
        }
    } catch {
        Write-Warning "$app - error deleting"
    }
}


pause
