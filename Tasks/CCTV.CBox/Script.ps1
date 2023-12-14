$Object = Invoke-WebRequest -Uri 'https://download.cntv.cn/cbox/update_config.txt' | Read-ResponseContent | ConvertFrom-Json

# Installer
$InstallerUrl = $Object.result.update_url
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl
}

# Version
$Task.CurrentState.Version = [regex]::Match($InstallerUrl, '_v([\d\.]+)_').Groups[1].Value

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object.status.now | Get-Date | ConvertTo-UtcDateTime -Id 'China Standard Time'

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 }) {
    $Task.Submit()
  }
}
