$Object = Invoke-RestMethod -Uri 'https://ideservice.alipay.com/ide/api/pluginVersion.json?platform=win&clientType=assistant' -Headers @{ Referer = 'https://openhome.alipay.com' }

# Version
$Task.CurrentState.Version = $Object.baseResponse.data.versionName

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.baseResponse.data.downloadUrl
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
