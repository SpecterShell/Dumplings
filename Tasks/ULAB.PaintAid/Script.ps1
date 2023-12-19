$Object1 = Invoke-RestMethod -Uri 'http://pa.udongman.cn/index.php/upgrade/'

# Version
$this.CurrentState.Version = $Object1.updater.pa_mversion + '.' + $Object1.updater.pa_subversion

# Installer
$InstallerUrl = $Object1.updater.TypeWin.package_url + $Object1.updater.TypeWin.package.name | ConvertTo-Https
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl
}

# ReleaseTime
$this.CurrentState.ReleaseTime = [datetime]::ParseExact(
  [regex]::Match($InstallerUrl, '(\d{8})').Groups[1].Value,
  'yyyyMMdd',
  $null
).ToString('yyyy-MM-dd')

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $Object2 = Invoke-RestMethod -Uri "http://pa.udongman.cn/index.php/v2/version/detail?version=$($this.CurrentState.Version)"

    try {
      # ReleaseNotes (zh-CN)
      if ($Object2.data) {
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object2.data.data.func_description | Format-Text
        }
      } else {
        $this.Logging("No ReleaseNotes for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
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
