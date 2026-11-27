$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/zhitongblog/unterm/releases/latest'

# Version
# Release tags may use the short minor form (v0.74), while ci\build-msi.ps1 stamps the
# installer/Unterm.wxs Package Version attribute into the MSI file name and into ARP
# DisplayVersion, so the asset name is the value that reaches the manifest.
$X64Asset = $Object1.assets.Where({ $_.name -match '^Unterm-.+-x64\.msi$' }, 'First')[0]
$Arm64Asset = $Object1.assets.Where({ $_.name -match '^Unterm-.+-arm64\.msi$' }, 'First')[0]
if (-not $X64Asset -or -not $Arm64Asset) {
  throw 'The latest release does not provide Windows x64 and arm64 MSI installers.'
}
$X64Version = [regex]::Match($X64Asset.name, '^Unterm-(.+)-x64\.msi$').Groups[1].Value
$Arm64Version = [regex]::Match($Arm64Asset.name, '^Unterm-(.+)-arm64\.msi$').Groups[1].Value
if ($X64Version -ne $Arm64Version) {
  throw "The x64 and arm64 MSI assets report different versions: $X64Version and $Arm64Version."
}
$this.CurrentState.Version = $X64Version

# Installer
# The .dmg, .deb, .AppImage and Windows .zip assets are non-MSI payloads, and the zip is the
# raw staged release tree with unterm.pdb, so only the two MSIs are selected.
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = $X64Asset.browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'wix'
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

    try {
      # The release body is empty, so CHANGELOG.md is the release-note source.
      # ReleaseNotes (en-US) and ReleaseNotesUrl (en-US)
      $Changelog = Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/zhitongblog/unterm/HEAD/CHANGELOG.md' | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis'
      $ReleaseNotesTitleNode = $Changelog.SelectSingleNode("/h2[contains(text(), '$X64Version')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = 'https://github.com/zhitongblog/unterm/blob/HEAD/CHANGELOG.md#' + ($ReleaseNotesTitleNode.InnerText -replace '[^a-zA-Z0-9\-\s]+', '' -replace '\s', '-').ToLower()
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
