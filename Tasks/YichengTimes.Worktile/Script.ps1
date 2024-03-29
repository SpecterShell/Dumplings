$Object1 = Invoke-RestMethod -Uri 'https://worktile.com/api/mobile/version/check?type=windows'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object1.data.path
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, 'worktile-([\d\.]+)').Groups[1].Value

# RealVersion
$this.CurrentState.RealVersion = $this.CurrentState.Version.Split('.')[0..2] -join '.'

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.data.date | ConvertFrom-UnixTimeSeconds

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object1.data.desc | Format-Text
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
