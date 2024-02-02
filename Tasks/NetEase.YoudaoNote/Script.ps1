$Prefix = 'https://artifact.lx.netease.com/download/ynote-electron/'

$Object1 = Invoke-WebRequest -Uri "${Prefix}latest-windows.yml?noCache=$(Get-Random)" | Read-ResponseContent | ConvertFrom-Yaml

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Prefix + $Object1.files[0].url
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.releaseDate | Get-Date -AsUTC

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = ($Object1.releaseNotes | ConvertTo-LF | Format-Text) -creplace '(?m)_+$', ''
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
