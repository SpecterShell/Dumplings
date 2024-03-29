$Object1 = (Invoke-RestMethod -Uri 'https://api.start.qq.com/cfg/get?biztypes=windows-update-info').configs.'windows-update-info'.value | ConvertFrom-Json

# Version
$this.CurrentState.Version = $Object1.latestversion

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.downloadurl.Replace('dldir1.qq.com', 'dldir1v6.qq.com')
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.updatedate | Get-Date -Format 'yyyy-MM-dd'

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object1.whatsnew | Format-Text
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
