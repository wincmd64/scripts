<#
Toggles the Windows Firewall default outbound policy
for all network profiles (Domain, Private, Public).

Modes:
  .\network.ps1           displays the current outbound policy state
  .\network.ps1 on        sets DefaultOutboundAction to Allow
  .\network.ps1 off       sets DefaultOutboundAction to Block

Administrative privileges are required.
#>

param(
    [ValidateSet("on","off","status")]
    [string]$Mode = "status"
)

switch ($Mode) {
    "off" {
        Set-NetFirewallProfile -Profile Domain,Private,Public -DefaultOutboundAction Block
        Write-Host "Outbound: BLOCKED"
    }
    "on" {
        Set-NetFirewallProfile -Profile Domain,Private,Public -DefaultOutboundAction Allow
        Write-Host "Outbound: ALLOWED"
    }
    "status" {
        Get-NetFirewallProfile -Profile Domain,Private,Public |
        Select-Object Name, DefaultOutboundAction
    }
}