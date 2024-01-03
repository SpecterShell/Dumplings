# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = Get-RedirectedUrl -Uri 'https://www.iflyrec.com/download/tjzs/win'
}

# Version
$this.CurrentState.Version = $Version = [regex]::Match($InstallerUrl, '_v([\d\.]+)').Groups[1].Value

if ($LocalStorage.Contains('iFlyRecMeeting') -and $LocalStorage.iFlyRecMeeting.Contains($Version)) {
  # ReleaseNotes (en-US)
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'en-US'
    Key    = 'ReleaseNotes'
    Value  = $LocalStorage.iFlyRecMeeting.$Version.ReleaseNotesEN
  }
  # ReleaseNotes (zh-CN)
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'zh-CN'
    Key    = 'ReleaseNotes'
    Value  = $LocalStorage.iFlyRecMeeting.$Version.ReleaseNotesCN
  }
} else {
  $this.Logging("No ReleaseNotes for version $($this.CurrentState.Version)", 'Warning')
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
