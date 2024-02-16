$Object1 = Invoke-RestMethod -Uri 'https://www.zotero.org/download/client/update/0/0/WINNT_x86/en-US/release/update.xml'

# Version
$this.CurrentState.Version = $Object1.updates.update.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = Get-RedirectedUrl -Uri "https://www.zotero.org/download/client/dl?channel=release&platform=win32&version=$($this.CurrentState.Version)"
}

# Sometimes the installer does not match the version
if (-not $InstallerUrl.Contains($this.CurrentState.Version)) {
  $this.Log('The installer does not match the version', 'Warning')

  # Version
  $this.CurrentState.Version = [regex]::Match($InstallerUrl, 'Zotero-([\d\.]+)').Groups[1].Value
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    try {
      $Uri2 = 'https://www.zotero.org/support/changelog'
      $Object2 = Invoke-WebRequest -Uri $Uri2 | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//h2[starts-with(@id, 'changes_in_$($this.CurrentState.Version.Replace('.', ''))')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.InnerText, '\((.+?)\)').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling.NextSibling; $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }

        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $Uri2 + '#' + $ReleaseNotesTitleNode.Attributes['id'].Value
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $Uri2
        }
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
