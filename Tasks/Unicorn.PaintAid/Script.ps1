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

switch (Compare-State) {
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
        Write-Host -Object "Task $($Task.Name): No ReleaseNotes for version $($Task.CurrentState.Version)" -ForegroundColor Yellow
      }
    } catch {
      Write-Host -Object "Task $($Task.Name): ${_}" -ForegroundColor Yellow
    }

    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
