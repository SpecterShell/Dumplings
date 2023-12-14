$Object = Invoke-RestMethod -Uri 'https://ideservice.alipay.com/ide/api/pluginVersion.json?platform=win&clientType=assistant' -Headers @{ Referer = 'https://openhome.alipay.com' }

# Version
$Task.CurrentState.Version = $Object.baseResponse.data.versionName

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.baseResponse.data.downloadUrl
}

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
