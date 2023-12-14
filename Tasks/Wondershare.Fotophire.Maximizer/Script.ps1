$Task.CurrentState = Invoke-WondershareXmlUpgradeApi -ProductId 3313 -Version '1.0.0' -Locale 'en-US'

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://download.wondershare.com/cbs_down/fotophire-maximizer_full3313.exe'
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
