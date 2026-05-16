$Prefix = 'https://static.keet.io/downloads/'
$DownloadsPage = Invoke-WebRequest -Uri $Prefix | Read-ResponseContent

$ReleaseEntries = [regex]::Matches(
  $DownloadsPage,
  '<a href="(?<Version>\d+\.\d+\.\d+)/">\k<Version>/</a>\s+(?<ReleaseTime>\d{2}-[A-Za-z]{3}-\d{4}\s+\d{2}:\d{2})'
) | ForEach-Object -Process {
  [ordered]@{
    Version     = $_.Groups['Version'].Value
    ReleaseTime = $_.Groups['ReleaseTime'].Value
  }
} | Sort-Object -Property @{ Expression = { [version]$_.Version } } -Descending

if (-not $ReleaseEntries) {
  throw 'Could not determine latest Keet version'
}

$LatestRelease = $ReleaseEntries[0]
$UrlVersion = $LatestRelease.Version
$InstallerUrl = "${Prefix}${UrlVersion}/Keet.msix"
$ReleaseTime = $null

try {
  $ReleaseTime = [datetime]::ParseExact($LatestRelease.ReleaseTime, 'dd-MMM-yyyy HH:mm', [System.Globalization.CultureInfo]::InvariantCulture)
} catch {
  $_ | Out-Host
  $this.Log($_, 'Warning')
}

$InstallerSha256 = $null
try {
  $Checksums = Invoke-WebRequest -Uri "${Prefix}${UrlVersion}/checksums.txt" | Read-ResponseContent
  $ChecksumMatch = [regex]::Match($Checksums, '(?im)^(?<Sha256>[a-f0-9]{64})\s+\*?Keet\.msix$')
  if ($ChecksumMatch.Success) {
    $InstallerSha256 = $ChecksumMatch.Groups['Sha256'].Value.ToUpperInvariant()
  } else {
    $this.Log("No SHA256 checksum found for version ${UrlVersion}", 'Warning')
  }
} catch {
  $_ | Out-Host
  $this.Log($_, 'Warning')
}

if (-not $InstallerSha256) {
  $InstallerFile = Get-TempFile -Uri $InstallerUrl
  $InstallerSha256 = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
  Remove-Item -Path $InstallerFile -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
}

# Set version
$this.CurrentState.Version = "${UrlVersion}.0"

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
