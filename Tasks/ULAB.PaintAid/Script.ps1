$Object1 = Invoke-RestMethod -Uri 'http://pa.udongman.cn/index.php/upgrade/'

# Version
$Task.CurrentState.Version = $Object1.updater.pa_mversion + '.' + $Object1.updater.pa_subversion

# Installer
$InstallerUrl = $Object1.updater.TypeWin.package_url + $Object1.updater.TypeWin.package.name | ConvertTo-Https
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = [datetime]::ParseExact(
  [regex]::Match($InstallerUrl, '(\d{8})').Groups[1].Value,
  'yyyyMMdd',
  $null
).ToString('yyyy-MM-dd')

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Object2 = Invoke-RestMethod -Uri "http://pa.udongman.cn/index.php/v2/version/detail?version=$($Task.CurrentState.Version)"

    try {
      # ReleaseNotes (zh-CN)
      if ($Object2.data) {
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object2.data.data.func_description | Format-Text
        }
      } else {
        $Task.Logging("No ReleaseNotes for version $($Task.CurrentState.Version)", 'Warning')
      }
    } catch {
      $Task.Logging($_, 'Warning')
    }

    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 }) {
    $Task.Submit()
  }
}
