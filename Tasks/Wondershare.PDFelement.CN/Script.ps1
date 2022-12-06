$Task.CurrentState = Invoke-WondershareXmlUpgradeApi -ProductId 5387 -Version '8.0.0.0' -Locale 'zh-CN'

# Installer
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = "https://cc-download.wondershare.cc/cbs_down/pdfelement_$($Task.CurrentState.Version)_full5387.exe"
}
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://cc-download.wondershare.cc/cbs_down/pdfelement_64bit_$($Task.CurrentState.Version)_full5387.exe"
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
