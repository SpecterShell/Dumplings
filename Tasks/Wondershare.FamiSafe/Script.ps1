$Task.CurrentState = Invoke-WondershareXmlUpgradeApi -ProductId 7740 -Version '1.0.0.0' -Locale 'en-US'

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://download.wondershare.com/cbs_down/famisafe_$($Task.CurrentState.Version)_full7740.exe"
}

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
