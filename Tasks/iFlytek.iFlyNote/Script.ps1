# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = Get-RedirectedUrl -Uri 'https://download.iflynote.com/voicenote_pc_win'
}

# Version
$this.CurrentState.Version = $Version = [regex]::Match($InstallerUrl, '-(\d+\.\d+\.\d+)[-.]').Groups[1].Value

if ($LocalStorage.Contains('iFlyNote1') -and $LocalStorage['iFlyNote1'].Contains($Version)) {
  # ReleaseNotes (zh-CN)
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'zh-CN'
    Key    = 'ReleaseNotes'
    Value  = $LocalStorage['iFlyNote1'].$Version.ReleaseNotesCN
  }
} else {
  $this.Logging("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
}

if ($LocalStorage.Contains('iFlyNote2') -and $LocalStorage['iFlyNote2'].Contains($Version)) {
  # ReleaseTime
  $this.CurrentState.ReleaseTime = $LocalStorage['iFlyNote2'].$Version.ReleaseTime
} else {
  $this.Logging("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
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
