$Task.CurrentState = Invoke-WondershareXmlUpgradeApi -ProductId 3314 -Version '1.0.0' -Locale 'en-US'

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://download.wondershare.com/cbs_down/fotophire-focus_full3314.exe'
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
