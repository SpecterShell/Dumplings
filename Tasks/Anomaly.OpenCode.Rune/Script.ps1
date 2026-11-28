$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/anomalyco/opencode-rune/releases/latest'

# Version
$this.CurrentState.Version = $Object1.tag_name -replace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture      = 'x64'
  InstallerType     = 'exe'
  InstallerSwitches = [ordered]@{
    Silent             = '/S'
    SilentWithProgress = '/S'
    InstallLocation    = '--dir "<INSTALLPATH>"'
    Log                = '--log "<LOGPATH>"'
  }
  InstallerUrl      = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('windows-x64') -and $_.name -match 'setup' }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture      = 'arm64'
  InstallerType     = 'exe'
  InstallerSwitches = [ordered]@{
    Silent             = '/S'
    SilentWithProgress = '/S'
    InstallLocation    = '--dir "<INSTALLPATH>"'
    Log                = '--log "<LOGPATH>"'
  }
  InstallerUrl      = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('windows-arm64') -and $_.name -match 'setup' }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()

      if (-not [string]::IsNullOrWhiteSpace($Object1.body)) {
        # The trailing "Full Changelog" line is repository metadata rather than a product change
        $Body = ($Object1.body -split '\r?\n' | Where-Object { $_ -notmatch '^\s*\*\*Full Changelog\*\*' }) -join "`n"
        $ReleaseNotesObject = $Body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak'

        $ReleaseNotesTitleNode = $ReleaseNotesObject.SelectSingleNode("./h2[contains(text(), `"What's Changed`")]")
        if ($ReleaseNotesTitleNode) {
          $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
          # ReleaseNotes (en-US)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
          }
        } else {
          $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $Object1.html_url
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
