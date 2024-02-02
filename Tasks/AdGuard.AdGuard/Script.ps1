$Object1 = Invoke-RestMethod -Uri 'https://api.adguard.org/api/2.0/checkupdate.html?app_id=64dbc91754f34b0ebcc6eecadf83eb81&channel=Release&appname=adguard_ru&version=7.0.0.0&force=1'

# Version
$this.CurrentState.Version = $Object1.response.version.'#cdata-section'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.response.'update-url'.'#cdata-section'
}

$ReleaseNotesTitleNode = (($Object1.response.'release-notes'.'#cdata-section' | ConvertFrom-Markdown).Html | ConvertFrom-Html).SelectSingleNode("./h1[text()='$($this.CurrentState.Version)']")
if ($ReleaseNotesTitleNode) {
  $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node.Name -ne 'h1'; $Node = $Node.NextSibling) { $Node }
  # ReleaseNotes (en-US)
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'en-US'
    Key    = 'ReleaseNotes'
    Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
  }
} else {
  $this.Logging("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
}

# ReleaseNotesUrl
$this.CurrentState.Locale += [ordered]@{
  Key   = 'ReleaseNotesUrl'
  Value = $Object1.response.'more-info-url'.'#cdata-section'
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
