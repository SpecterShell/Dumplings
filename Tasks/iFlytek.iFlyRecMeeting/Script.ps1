# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = Get-RedirectedUrl -Uri 'https://www.iflyrec.com/download/tjzs/win'
}

# Version
$this.CurrentState.Version = $Version = [regex]::Match($InstallerUrl, '_v([\d\.]+)[_.]').Groups[1].Value

if ($Global:DumplingsStorage.Contains('iFlyRecMeeting') -and $Global:DumplingsStorage.iFlyRecMeeting.Contains($Version)) {
  # ReleaseNotes (en-US)
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'en-US'
    Key    = 'ReleaseNotes'
    Value  = $Global:DumplingsStorage.iFlyRecMeeting.$Version.ReleaseNotesEN
  }
  # ReleaseNotes (zh-CN)
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'zh-CN'
    Key    = 'ReleaseNotes'
    Value  = $Global:DumplingsStorage.iFlyRecMeeting.$Version.ReleaseNotesCN
  }
} else {
  $this.Log("No ReleaseNotes for version $($this.CurrentState.Version)", 'Warning')
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
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
