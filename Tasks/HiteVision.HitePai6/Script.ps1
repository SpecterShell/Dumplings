$Object1 = $LocalStorage.HiteVisionApps['6AD336C7-7204-444D-BAE6-B1010B13888B']

# Version
$this.CurrentState.Version = $Object1.appVersion

# RealVersion
$this.CurrentState.RealVersion = $this.CurrentState.Version.Split('.')[0..2] -join '.'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.packageDownloadUrl
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.createTime | Get-Date | ConvertTo-UtcDateTime -Id 'China Standard Time'

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    try {
      $Object2 = Invoke-RestMethod -Uri 'https://update.hitecloud.cn/api/firewares/upwarenew?productmodel=HitePai6&buildversion=0'

      if ($Object2.data.version -eq $this.CurrentState.Version) {
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object2.data.firewarelog | Format-Text
        }
      } else {
        $this.Logging("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Logging($_, 'Warning')
    }

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
