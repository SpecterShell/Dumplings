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
