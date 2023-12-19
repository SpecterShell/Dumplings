$Prefix = 'https://artifact.lx.netease.com/download/ynote-electron/'

$Object = Invoke-WebRequest -Uri "${Prefix}latest-windows.yml?noCache=$((New-Guid).Guid.Split('-')[0])" | Read-ResponseContent | ConvertFrom-Yaml

# Version
$this.CurrentState.Version = $Object.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Prefix + $Object.files[0].url
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object.releaseDate | Get-Date -AsUTC

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = ($Object.releaseNotes | ConvertTo-LF | Format-Text) -creplace '(?m)_+$', ''
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
