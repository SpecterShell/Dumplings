$Object1 = Invoke-GitHubApi -Uri "https://api.github.com/repos/brave/brave-browser/releases/latest"

# Version
$this.CurrentState.Version = "$([regex]::Match($Object1.name, 'Chromium (\d+)').Groups[1].Value).$([regex]::Match($Object1.name, 'v(\d+(?:\.\d+)+)').Groups[1].Value)"

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  Scope        = 'user'
  InstallerUrl = $Object1.assets.Where({ $_.name -match 'BraveBrowserStandalone' -and $_.name.EndsWith('Setup32.exe') -and $_.name -match 'Silent' }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  Scope        = 'machine'
  InstallerUrl = $Object1.assets.Where({ $_.name -match 'BraveBrowserStandalone' -and $_.name.EndsWith('Setup32.exe') -and $_.name -notmatch 'Silent' }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  Scope        = 'user'
  InstallerUrl = $Object1.assets.Where({ $_.name -match 'BraveBrowserStandalone' -and $_.name.EndsWith('Setup.exe') -and $_.name -match 'Silent' }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  Scope        = 'machine'
  InstallerUrl = $Object1.assets.Where({ $_.name -match 'BraveBrowserStandalone' -and $_.name.EndsWith('Setup.exe') -and $_.name -notmatch 'Silent' }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  Scope        = 'user'
  InstallerUrl = $Object1.assets.Where({ $_.name -match 'BraveBrowserStandalone' -and $_.name.EndsWith('SetupArm64.exe') -and $_.name -match 'Silent' }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  Scope        = 'machine'
  InstallerUrl = $Object1.assets.Where({ $_.name -match 'BraveBrowserStandalone' -and $_.name.EndsWith('SetupArm64.exe') -and $_.name -notmatch 'Silent' }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/brave/brave-browser/master/CHANGELOG_DESKTOP.md' | Convert-MarkdownToHtml

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("/h2[contains(.//text(), '$($this.CurrentState.Version.Split('.')[1..3] -join '.')')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = ($ReleaseNotesNodes | Get-TextContent) -replace 'Released \d{4}-\d{1,2}-\d{1,2}\n' | Format-Text
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
