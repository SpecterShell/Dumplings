# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = Get-RedirectedUrl -Uri 'https://tongchuan.iflyrec.com/download/tjhz/windows/TJTC001'
}

# Version
$this.CurrentState.Version = $Version = [regex]::Match($InstallerUrl, '_(\d+\.\d+\.\d+)[_.]').Groups[1].Value

if ($Global:DumplingsStorage.Contains('iFlyRecSI1') -and $Global:DumplingsStorage['iFlyRecSI1'].Contains($Version)) {
  # ReleaseTime
  $this.CurrentState.ReleaseTime = $Global:DumplingsStorage['iFlyRecSI1'].$Version.ReleaseTime
} else {
  $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
}

if ($Global:DumplingsStorage.Contains('iFlyRecSI2') -and $Global:DumplingsStorage['iFlyRecSI2'].Contains($Version)) {
  # ReleaseNotes (zh-CN)
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'zh-CN'
    Key    = 'ReleaseNotes'
    Value  = $Global:DumplingsStorage['iFlyRecSI2'].$Version.ReleaseNotesCN
  }
} else {
  $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Write()
  }
  'Changed|Updated' {
    $this.Print()
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
