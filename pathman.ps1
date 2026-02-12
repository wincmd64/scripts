# Adds (or removes if exist) a directory to the user PATH environment variable
# Use -List to show all paths
# Add -Recurse to include all first-level subdirectories
# by github.com/wincmd64

param(
    [string]$Path,
    [switch]$List,
    [switch]$Recurse
)

# List current user PATH if -List is specified
if ($List) { [System.Environment]::GetEnvironmentVariable('PATH', 'User') -split [IO.Path]::PathSeparator | Write-Host; exit 0 }
# If no path provided, use current directory
if (-not $Path) { $Path = $PWD.Path }
# Validate path
if (-not (Test-Path -LiteralPath $Path)) { Write-Warning "The directory '$Path' does not exist."; exit 1 }
if (-not (Test-Path -LiteralPath $Path -PathType Container)) {Write-Warning "The path '$Path' is a file. You can only add directories to PATH."; exit 1}
if (-not ([IO.Path]::IsPathRooted($Path))) { Write-Warning "Only absolute paths or UNC are allowed."; exit 1 }

# Get paths with recursion consideration
function Get-PathsToProcess {
    param([string]$BasePath, [bool]$Recurse)
    
    $paths = @($BasePath.TrimEnd('\'))
    if (-not $Recurse) { return $paths }
    
    # Get only first-level subdirectories
    try {
        Get-ChildItem -LiteralPath $BasePath -Directory -ErrorAction Stop | ForEach-Object {
            $paths += $_.FullName
        }
    }
    catch {
        Write-Warning "Cannot access subdirectories of '$BasePath': $($_.Exception.Message)"
    }
    
    return $paths
}

# Get paths to process
$pathsToProcess = Get-PathsToProcess -BasePath $Path -Recurse $Recurse.IsPresent

# Get current User PATH
$currentPath = [System.Environment]::GetEnvironmentVariable('PATH', 'User')
# Split PATH into array
$arrPath = if ([string]::IsNullOrEmpty($currentPath)) { @() } else { $currentPath -split [IO.Path]::PathSeparator }

# Process all paths
$pathsToAdd = @()
$pathsToRemove = @()

foreach ($processingPath in $pathsToProcess) {
    # Check if already exists + removing trailing backslashes
    if ($arrPath -contains $processingPath) {
        $pathsToRemove += $processingPath
    } else {
        $pathsToAdd += $processingPath
    }
}

# Execute operations
if ($pathsToRemove.Count -gt 0) {
    Write-Host "`n Remove from PATH:" -ForegroundColor Magenta
    $pathsToRemove | ForEach-Object { Write-Host "  $_" }
    $arrPath = $arrPath | Where-Object { $_ -notin $pathsToRemove }
}

if ($pathsToAdd.Count -gt 0) {
    Write-Host "`n Add to PATH:" -ForegroundColor Green
    $pathsToAdd | ForEach-Object { Write-Host "  $_" }
    if (-not $PSBoundParameters.ContainsKey('Path')) {  # Ask for confirmation only when using current directory
        Write-Host "`n Add the current directory to PATH ?`n"
        pause
    }
    $arrPath = $arrPath + $pathsToAdd
}

# Apply changes
$newPath = $arrPath -join [IO.Path]::PathSeparator
[System.Environment]::SetEnvironmentVariable('PATH', $newPath, 'User')
Write-Host "`n DONE.`n"
sleep 1