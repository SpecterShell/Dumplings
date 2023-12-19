$Object1 = Invoke-RestMethod -Uri 'https://www.zotero.org/download/client/update/0/0/WINNT_x86/en-US/release/update.xml'

# Version
$this.CurrentState.Version = $Version = $Object1.updates.update.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = Get-RedirectedUrl -Uri "https://www.zotero.org/download/client/dl?channel=release&platform=win32&version=${Version}"
}

# Sometimes the installer does not match the version
if (-not $InstallerUrl.Contains($Version)) {
  $this.Logging('The installer does not match the version', 'Warning')

  # Version
  $this.CurrentState.Version = [regex]::Match($InstallerUrl, 'Zotero-([\d\.]+)').Groups[1].Value
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $Uri2 = 'https://www.zotero.org/support/changelog'
    $Object2 = Invoke-WebRequest -Uri $Uri2 | ConvertFrom-Html

    try {
      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//h2[starts-with(@id, 'changes_in_$($Version.Replace('.', ''))')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.InnerText, '\((.+?)\)').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        $ReleaseNotesNodes = @()
        for ($Node = $ReleaseNotesTitleNode.NextSibling.NextSibling; $Node.Name -ne 'h2'; $Node = $Node.NextSibling) {
          $ReleaseNotesNodes += $Node
        }

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
        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $Uri2
        }

        $this.Logging("No ReleaseNotes for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $this.Logging($_, 'Warning')
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
