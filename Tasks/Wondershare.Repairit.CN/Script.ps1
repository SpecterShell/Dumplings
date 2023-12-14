$Task.CurrentState = Invoke-WondershareXmlUpgradeApi -ProductId 11009 -Version '1.0.0.0' -Locale 'zh-CN'

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://cc-download.wondershare.cc/cbs_down/repairit_$($Task.CurrentState.Version)_full11009.exe"
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
