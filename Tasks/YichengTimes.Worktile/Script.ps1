$Object = Invoke-RestMethod -Uri 'https://worktile.com/api/mobile/version/check?type=windows'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object.data.path
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, 'worktile-(\d+\.\d+\.\d+)').Groups[1].Value

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object.data.date | ConvertFrom-UnixTimeSeconds

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.data.desc | Format-Text
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
