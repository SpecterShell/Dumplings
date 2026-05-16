# Script to update Holepunch.Keet manifest
# Keet is distributed via MSIX from https://static.keet.io/downloads/

# Fetch the directory listing from the downloads page
try {
  $DownloadsPage = Invoke-WebRequest -Uri 'https://static.keet.io/downloads/' -ErrorAction SilentlyContinue
  
  # Parse version directories from the HTML directory listing
  # Look for href links like <a href="4.15.0/">4.15.0/</a>
  $VersionMatches = [regex]::Matches($DownloadsPage.Content, '<a href="(\d+\.\d+\.\d+)/">(\d+\.\d+\.\d+)</a>')
  
  if ($VersionMatches.Count -gt 0) {
    # Extract version numbers and sort them to find the latest
    $Versions = $VersionMatches | ForEach-Object { $_.Groups[1].Value } | 
      Sort-Object -Property @{ Expression = { [version]$_ } } -Descending
    
    $Version = $Versions[0]
  }
  
  # Try to get the release date from the directory listing
  # The HTML shows dates like "15-May-2026 21:44"
  $VersionDates = [regex]::Matches($DownloadsPage.Content, "<a href=""$([regex]::Escape($Version))/"">$([regex]::Escape($Version))</a>\s+(\d+-\w+-\d+\s+\d+:\d+)")
  
  if ($VersionDates.Count -gt 0) {
    try {
      $DateString = $VersionDates[0].Groups[1].Value
      # Parse date string like "15-May-2026 21:44"
      $ReleaseTime = [datetime]::ParseExact($DateString, 'dd-MMM-yyyy HH:mm', [cultureinfo]::InvariantCulture)
    } catch {
      Write-Warning "Could not parse release date: $_"
    }
  }
} catch {
  Write-Warning "Could not fetch downloads page: $_"
}

if (-not $Version) {
  Write-Warning "Could not determine latest Keet version"
  exit
}

# Normalize version to standard format for winget (e.g., 4.15.0 -> 4.15.0.0)
if ($Version -notmatch '\d+\.\d+\.\d+\.\d+') {
  if ($Version -match '^\d+\.\d+\.\d+$') {
    $Version = "$Version.0"
  }
}

# Get installer URL - use the three-part version (strip the .0 we added)
$UrlVersion = $Version -replace '\.0$'
$InstallerUrl = "https://static.keet.io/downloads/$UrlVersion/Keet.msix"

# Try to get SHA256 hash
$InstallerSha256 = $null
try {
  $Response = Invoke-WebRequest -Uri $InstallerUrl -Method Head -ErrorAction SilentlyContinue
  if ($Response.StatusCode -eq 200) {
    # Download the file to compute hash (this can be slow)
    $TempFile = [System.IO.Path]::GetTempFileName()
    Invoke-WebRequest -Uri $InstallerUrl -OutFile $TempFile -ErrorAction SilentlyContinue
    $InstallerSha256 = (Get-FileHash -Path $TempFile -Algorithm SHA256).Hash
    Remove-Item -Path $TempFile -Force
  }
} catch {
  Write-Warning "Could not compute hash for installer: $_"
}

# Set version
$this.CurrentState.Version = $Version

# Add installer information for x64
$InstallerInfo1 = [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'msix'
  InstallerUrl  = $InstallerUrl
}
if ($InstallerSha256) {
  $InstallerInfo1['InstallerSha256'] = $InstallerSha256
}
$this.CurrentState.Installer += $InstallerInfo1

# Add installer information for arm64
$InstallerInfo2 = [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'msix'
  InstallerUrl  = $InstallerUrl
}
if ($InstallerSha256) {
  $InstallerInfo2['InstallerSha256'] = $InstallerSha256
}
$this.CurrentState.Installer += $InstallerInfo2

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      if ($ReleaseTime) {
        $this.CurrentState.ReleaseTime = $ReleaseTime
      }

      # Add locale information (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'Documentations'
        Value  = @(
          [ordered]@{
            DocumentLabel = 'GitHub'
            DocumentUrl   = 'https://github.com/holepunchto/keet'
          }
          [ordered]@{
            DocumentLabel = 'Website'
            DocumentUrl   = 'https://keet.io/'
          }
        )
      }

      # Add license information
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'LicenseUrl'
        Value  = 'https://github.com/holepunchto/keet/blob/main/LICENSE'
      }

      $this.Print()
      $this.Write()
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }
  }
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
