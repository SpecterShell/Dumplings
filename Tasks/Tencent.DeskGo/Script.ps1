$Object1 = (Invoke-RestMethod -Uri 'https://s.pcmgr.qq.com/tapi/web/searchcgi.php?type=search&keyword=腾讯桌面整理').list.Where({ $_.SoftID -eq 23125 }, 'First')[0].xmlInfo | ConvertFrom-Xml

# Version
$this.CurrentState.Version = $Object1.soft.versionname

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.soft.url.'#cdata-section'
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.soft.publishdate | Get-Date -Format 'yyyy-MM-dd'

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object1.soft.whatsnew.'#cdata-section' | Format-Text
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
