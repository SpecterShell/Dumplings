$Object1 = Invoke-RestMethod -Uri 'https://www.zotero.org/download/client/update/0/0/WINNT_x86/en-US/release/update.xml?force=1'

# Version
$this.CurrentState.Version = $Object1.updates.update.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $InstallerUrl = Get-RedirectedUrl -Uri "https://www.zotero.org/download/client/dl?channel=release&platform=win32&version=$($this.CurrentState.Version)"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrl = Get-RedirectedUrl -Uri "https://www.zotero.org/download/client/dl?channel=release&platform=win-x64&version=$($this.CurrentState.Version)"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = $InstallerUrl = Get-RedirectedUrl -Uri "https://www.zotero.org/download/client/dl?channel=release&platform=win-arm64&version=$($this.CurrentState.Version)"
}

# Sometimes the installer does not match the version
if (-not $InstallerUrl.Contains($this.CurrentState.Version)) {
  $this.Log('The installer does not match the version', 'Warning')

  # Version
  $this.CurrentState.Version = [regex]::Match($InstallerUrl, 'Zotero-([\d\.]+)').Groups[1].Value
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $RelaseNotesUrl = 'https://www.zotero.org/support/changelog'
      }

      $Object2 = Invoke-WebRequest -Uri $RelaseNotesUrl | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//h2[starts-with(@id, 'changes_in_$($this.CurrentState.Version.Replace('.', ''))')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.InnerText, '\((.+?)\)').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }

        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $RelaseNotesUrl + '#' + $ReleaseNotesTitleNode.Attributes['id'].Value
        }
      } else {
        $this.Log("No ReleaseTime, ReleaseNotes (en-US) and ReleaseNotesUrl for version $($this.CurrentState.Version)", 'Warning')
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
