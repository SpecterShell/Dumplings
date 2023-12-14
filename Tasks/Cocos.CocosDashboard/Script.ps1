$EdgeDriver = Get-EdgeDriver
$EdgeDriver.Navigate().GoToUrl('https://www.cocos.com/creator-download')

$Object = $EdgeDriver.ExecuteScript('return window.__NUXT__.data[0].dashboardLatest', $null)

# Version
$Task.CurrentState.Version = $Object.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.win32_url
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object.publish_time | ConvertFrom-UnixTimeSeconds

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    # RealVersion
    $Task.CurrentState.RealVersion = Get-TempFile -Uri $Task.CurrentState.Installer[0].InstallerUrl | Read-ProductVersionFromExe

    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 }) {
    $Task.Submit()
  }
}
