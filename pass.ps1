# PASSWORD GENERATOR

param(
    [int]$length = 12,
    [int]$count = 1
)

$minLength = 8
$chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*'

# Ensure length is within reasonable bounds
if ($length -lt $minLength) {Write-Warning "Password length must be at least $minLength." ; exit}

# Function to generate a raw password using CSPRNG
function Get-RandomCandidate {
    param($l, $c)
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $charCount = $c.Length
    
    # Calculate the maximum fair value to avoid modulo bias
    $maxByte = [byte]::MaxValue - ([byte]::MaxValue % $charCount)
    
    $res = ""
    while ($res.Length -lt $l) {
        $byte = New-Object byte[](1)
        $rng.GetBytes($byte)
        
        # Only use the byte if it's within the fair range
        if ($byte[0] -lt $maxByte) {
            $res += $c[$byte[0] % $charCount]
        }
    }
    return $res
}

# Array to store all generated passwords for clipboard
$allPasswords = @()

Write-Host "`nGenerated Passwords:" -ForegroundColor Cyan

# Main loop for multiple password generation
for ($j = 0; $j -lt $count; $j++) {
    
    # Validation loop: Keep trying until all complexity criteria are met
    do {
        $password = Get-RandomCandidate -l $length -c $chars
    } while (
        $password -notmatch '[a-z]' -or 
        $password -notmatch '[A-Z]' -or 
        $password -notmatch '[0-9]' -or 
        $password -notmatch '[!@#$%^&*]'
    )

    $allPasswords += $password

    # Output with color coding per character type
    Write-Host "[$($j + 1)] " -NoNewline -ForegroundColor Gray
    foreach ($char in $password.ToCharArray()) {
        if ($char -match '[0-9]') {
            Write-Host -NoNewline -ForegroundColor Green $char
        } elseif ($char -match '[!@#$%^&*]') {
            Write-Host -NoNewline -ForegroundColor Yellow $char
        } else {
            Write-Host -NoNewline $char
        }
    }
    Write-Host "" 
}

# Join all passwords with newlines and copy to clipboard
$allPasswords -join "`r`n" | Set-Clipboard

Write-Host "`nCopied to clipboard.`n" -ForegroundColor DarkGray