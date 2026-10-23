param (
    [Parameter(Mandatory=$true)]
    [ValidateSet("major", "minor", "patch")]
    $type
)

$pubspecFile = "pubspec.yaml"
if (-not (Test-Path $pubspecFile)) {
    Write-Error "pubspec.yaml not found"
    exit 1
}

# Read pubspec content
$content = Get-Content $pubspecFile -Raw
if ($content -match "version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)") {
    $major = [int]$Matches[1]
    $minor = [int]$Matches[2]
    $patch = [int]$Matches[3]
    $build = [int]$Matches[4]
} else {
    Write-Error "Could not parse version from pubspec.yaml"
    exit 1
}

# Increment build number (always)
$newBuild = $build + 1

# Increment version numbers
switch ($type) {
    "major" { $major++; $minor = 0; $patch = 0 }
    "minor" { $minor++; $patch = 0 }
    "patch" { $patch++ }
}

$newVersion = "$major.$minor.$patch+$newBuild"
$newContent = $content -replace "version:\s*\d+\.\d+\.\d+\+\d+", "version: $newVersion"

# Save updated pubspec
Set-Content $pubspecFile $newContent -NoNewline

Write-Host "Updated version to: $newVersion"

# Git operations
git add $pubspecFile
git commit -m "Bump version to $newVersion"
git tag -a "v$major.$minor.$patch" -m "Release v$major.$minor.$patch (Build $newBuild)"

Write-Host "Committed and tagged v$major.$minor.$patch"
