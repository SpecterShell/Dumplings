# The published build is a prerelease, so releases/latest returns nothing and the whole list is needed.
$Object1 = @(Invoke-GitHubApi -Uri 'https://api.github.com/repos/lampka-app/lampka-releases/releases?per_page=100') |
  Where-Object -FilterScript { -not $_.draft } |
  Sort-Object -Property { [ChunkVersion]($_.tag_name -replace '^v') } -Bottom 1

if (-not $Object1) {
  throw 'The releases listing does not provide a published release.'
}

# Version
# The tag carries the prerelease suffix that the installer itself does not report, and the package
# version follows the installed version, so the suffix is dropped.
$this.CurrentState.Version = $Object1.tag_name -replace '^v' -replace '-.+$', ''

if ($this.CurrentState.Version -notmatch '^[0-9]+(\.[0-9]+)*$') {
  throw 'The highest release tag does not provide a usable version.'
}

# Installer
$Asset = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name -match 'Setup' -and $_.name -notmatch 'portable|update' }, 'First')[0]
if (-not $Asset) {
  throw 'The release does not provide a Windows setup installer.'
}
# Both scopes ship from one asset, so the parser can only read the per-user install location. Pin the
# scope-specific paths to keep the machine entry from inheriting them.
$InstallerUrl = $Asset.browser_download_url | ConvertTo-UnescapedUri
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x64'
  InstallerType        = 'inno'
  Scope                = 'user'
  InstallerUrl         = $InstallerUrl
  InstallationMetadata = [ordered]@{ DefaultInstallLocation = '%LocalAppData%\Programs\Lampka' }
}
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x64'
  InstallerType        = 'inno'
  Scope                = 'machine'
  InstallerUrl         = $InstallerUrl
  InstallationMetadata = [ordered]@{ DefaultInstallLocation = '%ProgramFiles%\Lampka' }
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$InstallerUrl] = $InstallerFile = Get-TempFile -Uri $InstallerUrl

    # The checksum asset swaps the installer extension for .sha256.txt, so match on the recorded
    # filename inside the text rather than rebuilding the name.
    $ChecksumAsset = $Object1.assets.Where({ $_.name.EndsWith('.sha256.txt') }, 'First')[0]
    if (-not $ChecksumAsset) {
      throw 'The release does not provide a .sha256.txt asset to verify the installer against.'
    }
    $ChecksumText = [string](Get-Content -LiteralPath (Get-TempFile -Uri $ChecksumAsset.browser_download_url) -Raw)
    $ExpectedHash = $null
    foreach ($Line in $ChecksumText | Split-LineEndings) {
      $Entries = $Line -split '\s+'
      if ($Entries[0] -match '^[0-9a-fA-F]{64}$' -and $Entries[1].TrimStart('*') -eq $Asset.name) {
        $ExpectedHash = $Entries[0]
        break
      }
    }
    if (-not $ExpectedHash) {
      throw "$($ChecksumAsset.name) does not list $($Asset.name)."
    }
    if ((Get-FileHash -LiteralPath $InstallerFile -Algorithm SHA256).Hash -ine $ExpectedHash) {
      throw "The downloaded installer does not match the SHA-256 published in $($ChecksumAsset.name)."
    }

    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = [string]$Object1.html_url
      }

      # The release body is only download, checksum-verification, and SmartScreen boilerplate, so it
      # supplies no ReleaseNotes.
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
