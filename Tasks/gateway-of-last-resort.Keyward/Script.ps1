$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/gateway-of-last-resort/keyward/releases/latest'

# Version
# goreleaser names the archives keyward_<version>_<os>_<arch>, with the tag's leading v stripped, and
# the Windows archives carry no installer, so the two Windows zips are the full portable artifacts.
$X64Asset = $Object1.assets.Where({ $_.name -match '^keyward_[0-9][0-9a-zA-Z.\-]*_windows_amd64\.zip$' }, 'First')[0]
$Arm64Asset = $Object1.assets.Where({ $_.name -match '^keyward_[0-9][0-9a-zA-Z.\-]*_windows_arm64\.zip$' }, 'First')[0]
if (-not $X64Asset -or -not $Arm64Asset) {
  throw 'The latest release does not provide Windows amd64 and arm64 archives.'
}
$X64Version = [regex]::Match($X64Asset.name, '^keyward_(.+)_windows_amd64\.zip$').Groups[1].Value
$Arm64Version = [regex]::Match($Arm64Asset.name, '^keyward_(.+)_windows_arm64\.zip$').Groups[1].Value
if ($X64Version -ne $Arm64Version) {
  throw "The amd64 and arm64 archives report different versions: $X64Version and $Arm64Version."
}
$this.CurrentState.Version = $X64Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'zip'
  InstallerUrl  = $X64Asset.browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'zip'
  InstallerUrl  = $Arm64Asset.browser_download_url | ConvertTo-UnescapedUri
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

    # The release publishes checksums.txt for every asset, so verify both archives against it.
    $ChecksumAsset = $Object1.assets.Where({ $_.name -eq 'checksums.txt' }, 'First')[0]
    if (-not $ChecksumAsset) {
      throw 'The latest release does not provide checksums.txt to verify the installers against.'
    }
    $ChecksumTable = @{}
    foreach ($Line in ([string](Get-Content -LiteralPath (Get-TempFile -Uri $ChecksumAsset.browser_download_url) -Raw) | Split-LineEndings)) {
      $Entries = $Line -split '\s+'
      if ($Entries[0] -match '^[0-9a-fA-F]{64}$') { $ChecksumTable[$Entries[1].TrimStart('*')] = $Entries[0] }
    }
    foreach ($Asset in @($X64Asset, $Arm64Asset)) {
      $ExpectedHash = $ChecksumTable[$Asset.name]
      if (-not $ExpectedHash) {
        throw "checksums.txt does not list $($Asset.name)."
      }
      $InstallerUrl = $Asset.browser_download_url | ConvertTo-UnescapedUri
      $this.InstallerFiles[$InstallerUrl] = $InstallerFile = Get-TempFile -Uri $InstallerUrl
      if ((Get-FileHash -LiteralPath $InstallerFile -Algorithm SHA256).Hash -ine $ExpectedHash) {
        throw "The downloaded $($Asset.name) does not match the SHA-256 published in checksums.txt."
      }
      foreach ($Installer in $this.CurrentState.Installer) {
        if ($Installer.InstallerUrl -ceq $InstallerUrl) { $Installer['InstallerSha256'] = $ExpectedHash.ToUpperInvariant() }
      }
    }

    try {
      # ReleaseNotes (en-GB) and ReleaseNotesUrl (en-GB)
      # The release body is a generated commit log with full SHA-1 prefixes, so CHANGELOG.md, which the
      # publisher maintains in Keep a Changelog form, is the release-note source. Its headings link the
      # version, so the h2 text is "1.1.0 - 2026-10-22" and the anchor keeps the link brackets removed.
      $Changelog = Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/gateway-of-last-resort/keyward/HEAD/CHANGELOG.md' | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis'
      $ReleaseNotesTitleNode = $Changelog.SelectSingleNode("/h2[contains(., '$X64Version')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-GB'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-GB'
          Key    = 'ReleaseNotesUrl'
          Value  = 'https://github.com/gateway-of-last-resort/keyward/blob/HEAD/CHANGELOG.md#' + ($ReleaseNotesTitleNode.InnerText -replace '[^a-zA-Z0-9\-\s]+', '' -replace '\s', '-').ToLower()
        }
      } else {
        $this.Log("No ReleaseNotes (en-GB) for version $($this.CurrentState.Version)", 'Warning')
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
