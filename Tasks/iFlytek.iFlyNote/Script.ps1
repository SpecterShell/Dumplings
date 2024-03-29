# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = Get-RedirectedUrl -Uri 'https://download.iflynote.com/voicenote_pc_win'
}

# Version
$this.CurrentState.Version = $Version = [regex]::Match($InstallerUrl, '-(\d+\.\d+\.\d+)[-.]').Groups[1].Value

if ($Global:DumplingsStorage.Contains('iFlyNote1') -and $Global:DumplingsStorage['iFlyNote1'].Contains($Version)) {
  # ReleaseNotes (zh-CN)
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'zh-CN'
    Key    = 'ReleaseNotes'
    Value  = $Global:DumplingsStorage['iFlyNote1'].$Version.ReleaseNotesCN
  }
} else {
  $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
}

if ($Global:DumplingsStorage.Contains('iFlyNote2') -and $Global:DumplingsStorage['iFlyNote2'].Contains($Version)) {
  # ReleaseTime
  $this.CurrentState.ReleaseTime = $Global:DumplingsStorage['iFlyNote2'].$Version.ReleaseTime
} else {
  $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
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
