$RepoOwner = 'quick-lint'
$RepoName = 'quick-lint-js'

$Object1 = Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/releases/latest"

# Version
$this.CurrentState.Version = $Object1.tag_name -creplace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'msix'
  InstallerUrl  = "https://c.quick-lint-js.com/releases/$($this.CurrentState.Version)/windows/quick-lint-js.msix"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'zip'
  InstallerUrl  = "https://c.quick-lint-js.com/releases/$($this.CurrentState.Version)/manual/windows-x86.zip"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'zip'
  InstallerUrl  = "https://c.quick-lint-js.com/releases/$($this.CurrentState.Version)/manual/windows.zip"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm'
  InstallerType = 'zip'
  InstallerUrl  = "https://c.quick-lint-js.com/releases/$($this.CurrentState.Version)/manual/windows-arm.zip"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'zip'
  InstallerUrl  = "https://c.quick-lint-js.com/releases/$($this.CurrentState.Version)/manual/windows-arm64.zip"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()

      if (-not [string]::IsNullOrWhiteSpace($Object1.body)) {
        $ReleaseNotesObject = $Object1.body | Convert-MarkdownToHtml -Extensions $MarkdigSoftlineBreakAsHardlineExtension
        if ($ReleaseNotesObject.SelectSingleNode('/p[.//a/text()="Downloads"]')) {
          # ReleaseNotes (en-US)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesObject.SelectNodes('/p[.//a/text()="Downloads"]/following-sibling::node()') | Get-TextContent | Format-Text
          }
        } else {
          # ReleaseNotes (en-US)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesObject | Get-TextContent | Format-Text
          }
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $Object1.html_url
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
