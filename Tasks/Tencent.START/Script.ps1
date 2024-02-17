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

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Print()
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
