# PASSWORD GENERATOR

param([int]$length = 12)

$minLength = 8
$chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*'

# Ensure length is within reasonable bounds
if ($length -lt $minLength) {Write-Warning "Password length must be at least $minLength." ; exit}

# Function to generate a raw password using CSPRNG
function Get-RandomCandidate {
    param($l, $c)
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $bytes = New-Object byte[]($l)
    $rng.GetBytes($bytes)
    
    $res = ""
    for ($i = 0; $i -lt $l; $i++) {
        $res += $c[$bytes[$i] % $c.Length]
    }
    return $res
}

# Validation loop: Keep trying until all criteria are met
do {
    $password = Get-RandomCandidate -l $length -c $chars
} while (
    $password -notmatch '[a-z]' -or 
    $password -notmatch '[A-Z]' -or 
    $password -notmatch '[0-9]' -or 
    $password -notmatch '[!@#$%^&*]'
)

# Output with color coding
Write-Host "`nGenerated: " -NoNewline
foreach ($char in $password.ToCharArray()) {
    if ($char -match '[0-9]') {
        Write-Host -NoNewline -ForegroundColor Green $char
    } elseif ($char -match '[!@#$%^&*]') {
        Write-Host -NoNewline -ForegroundColor Yellow $char
    } else {
        Write-Host -NoNewline $char
    }
}

# Finalize
$password | Set-Clipboard
Write-Host "`n`n Copied to clipboard.`n" -ForegroundColor Gray
