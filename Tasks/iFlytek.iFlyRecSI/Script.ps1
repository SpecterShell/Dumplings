# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = Get-RedirectedUrl -Uri 'https://tongchuan.iflyrec.com/download/tjhz/windows/TJTC001'
}

# Version
$this.CurrentState.Version = $Version = [regex]::Match($InstallerUrl, '_(\d+\.\d+\.\d+)[_.]').Groups[1].Value

if ($LocalStorage.Contains('iFlyRecSI1') -and $LocalStorage['iFlyRecSI1'].Contains($Version)) {
  # ReleaseTime
  $this.CurrentState.ReleaseTime = $LocalStorage['iFlyRecSI1'].$Version.ReleaseTime
} else {
  $this.Logging("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
}

if ($LocalStorage.Contains('iFlyRecSI2') -and $LocalStorage['iFlyRecSI2'].Contains($Version)) {
  # ReleaseNotes (zh-CN)
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'zh-CN'
    Key    = 'ReleaseNotes'
    Value  = $LocalStorage['iFlyRecSI2'].$Version.ReleaseNotesCN
  }
} else {
  $this.Logging("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
