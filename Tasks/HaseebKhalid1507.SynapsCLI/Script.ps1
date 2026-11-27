$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/HaseebKhalid1507/SynapsCLI/releases/latest'

# Version
# cargo-dist names the Windows archive without a version token, so the release tag is the version,
# and the announcement title and CHANGELOG heading repeat the same number.
$this.CurrentState.Version = [string]$Object1.tag_name -replace '^v'

# Installer
# Only the x86_64-pc-windows-msvc zip is a Windows payload; the tar.gz, .deb, source, per-asset
# .sha256, dist-manifest.json and installer scripts cover other platforms or are metadata.
$Asset = $Object1.assets.Where({ $_.name -eq 'synaps-x86_64-pc-windows-msvc.zip' }, 'First')[0]
if (-not $Asset) {
  throw 'The latest release does not provide a Windows x64 archive.'
}
$InstallerUrl = $Asset.browser_download_url | ConvertTo-UnescapedUri
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'zip'
  InstallerUrl  = $InstallerUrl
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

    # The release publishes sha256.sum for every asset, so verify the archive against it.
    $ChecksumAsset = $Object1.assets.Where({ $_.name -eq 'sha256.sum' }, 'First')[0]
    if (-not $ChecksumAsset) {
      throw 'The latest release does not provide sha256.sum to verify the installer against.'
    }
    $ChecksumTable = @{}
    foreach ($Line in ([string](Get-Content -LiteralPath (Get-TempFile -Uri $ChecksumAsset.browser_download_url) -Raw) | Split-LineEndings)) {
      $Entries = $Line -split '\s+'
      if ($Entries[0] -match '^[0-9a-fA-F]{64}$') { $ChecksumTable[$Entries[1].TrimStart('*')] = $Entries[0] }
    }
    $ExpectedHash = $ChecksumTable[$Asset.name]
    if (-not $ExpectedHash) {
      throw "sha256.sum does not list $($Asset.name)."
    }
    $this.InstallerFiles[$InstallerUrl] = $InstallerFile = Get-TempFile -Uri $InstallerUrl
    if ((Get-FileHash -LiteralPath $InstallerFile -Algorithm SHA256).Hash -ine $ExpectedHash) {
      throw "The downloaded $($Asset.name) does not match the SHA-256 published in sha256.sum."
    }
    $this.CurrentState.Installer[0]['InstallerSha256'] = $ExpectedHash.ToUpperInvariant()

    try {
      # ReleaseNotes (en-US) and ReleaseNotesUrl (en-US)
      # The release body opens with the summary and upgrade notes, then repeats the whole per-release
      # Added/Changed/Removed/Fixed/Internal changelog, which is far past the schema limit, so the
      # detailed lists and the trailing Install and Download sections are dropped at their headings.
      if ([string]::IsNullOrWhiteSpace($Object1.body)) {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      } else {
        $ReleaseNotesObject = $Object1.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak'
        $Skip = $false
        $SkippedHeadingLevel = 0
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesObject.ChildNodes[0].NextSibling; $Node; $Node = $Node.NextSibling) {
          if ($Node.Name -match '^h([1-6])$') {
            $HeadingLevel = [int]$Matches[1]
            if (-not $Skip -or $HeadingLevel -le $SkippedHeadingLevel) {
              $Skip = $Node.InnerText -match '^(Added|Changed|Removed|Fixed|Internal|Install|Download)\b'
              if ($Skip) { $SkippedHeadingLevel = $HeadingLevel }
            }
          }
          if (-not $Skip) { $Node }
        }
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = [string]$Object1.html_url
        }
      }
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
