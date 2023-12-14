$Task.CurrentState = Invoke-WondershareJsonUpgradeApi -ProductId 5793 -Version '1.0.0.0' -X86 -Locale 'en-US'

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://download.wondershare.com/cbs_down/mobiletrans_$($Task.CurrentState.Version)_full5793.exe"
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
