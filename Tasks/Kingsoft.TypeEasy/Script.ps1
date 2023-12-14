$EdgeDriver = Get-EdgeDriver
$EdgeDriver.Navigate().GoToUrl('https://www.51dzt.com/rubik-ssr/51dzt')

$Object = $EdgeDriver.ExecuteScript('return window.__NUXT__.state.application.project_components.filter(obj => obj.name == "dzt-banner")[0].user_props', $null)

# Version
$Task.CurrentState.Version = [regex]::Match($Object.downloadVersion, '（([\d\.]+)）').Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = (($Object.download | ConvertFrom-Json).event | Where-Object({ $_.type -eq 'openLink' })).params.url
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = [regex]::Match($Object.downloadVersion, '(\d{4}\.\d{1,2}\.\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

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
