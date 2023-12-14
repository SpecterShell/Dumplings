$Task.CurrentState = Invoke-WondershareJsonUpgradeApi -ProductId 4516 -Version '3.0.0' -Locale 'zh-CN'

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://cc-download.wondershare.cc/cbs_down/data-recovery-64bit_$($Task.CurrentState.Version)_full4516.exe"
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
