$Object = Invoke-RestMethod -Uri 'https://api.bilibili.com/pugv/web/livedata/getLatestVersion'

# Version
$Task.CurrentState.Version = $Object.data.win.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.data.win.url | ConvertTo-UnescapedUri | ConvertTo-Https
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
