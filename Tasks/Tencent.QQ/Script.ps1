$Object1 = (Invoke-WebRequest -Uri 'https://im.qq.com/pcqq').Content | Get-EmbeddedJson -StartsFrom 'window.__INITIAL_STATE__=' | ConvertFrom-Json

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object1.rainbowConfig.banner.downloadUrl.Replace('dldir1.qq.com', 'dldir1v6.qq.com')
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '(\d+\.\d+\.\d+\.\d+)').Groups[1].Value

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.rainbowConfig.banner.publishTime | Get-Date -Format 'yyyy-MM-dd'

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object1.rainbowConfig.banner.features | Format-Text
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
