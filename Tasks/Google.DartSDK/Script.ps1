$Object1 = Invoke-RestMethod -Uri 'https://storage.googleapis.com/dart-archive/channels/stable/release/latest/VERSION'

# Version
$this.CurrentState.Version = $Object1.version

# Installer
# $this.CurrentState.Installer += [ordered]@{
#   Architecture = 'x86'
#   InstallerUrl = "https://storage.googleapis.com/dart-archive/channels/stable/release/$($this.CurrentState.Version)/sdk/dartsdk-windows-ia32-release.zip"
# }
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://storage.googleapis.com/dart-archive/channels/stable/release/$($this.CurrentState.Version)/sdk/dartsdk-windows-x64-release.zip"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = "https://storage.googleapis.com/dart-archive/channels/stable/release/$($this.CurrentState.Version)/sdk/dartsdk-windows-arm64-release.zip"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.date | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $ReleaseNotesUrl = 'https://github.com/dart-lang/sdk/blob/HEAD/CHANGELOG.md'
      }

      $Object3 = Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/dart-lang/sdk/HEAD/CHANGELOG.md' | Convert-MarkdownToHtml

      $ReleaseNotesTitleNode = $Object3.SelectSingleNode("/h2[contains(text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }

        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $ReleaseNotesUrl + '#' + ($ReleaseNotesTitleNode.InnerText -creplace '[^a-zA-Z0-9\-\s]+', '' -creplace '\s+', '-').ToLower()
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) and ReleaseNotesUrl for version $($this.CurrentState.Version)", 'Warning')
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
