$Task.CurrentState = Invoke-WondershareXmlDownloadApi -ProductId 7920 -Wae '3.0.1'

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://download.wondershare.com/cbs_down/inclowdz_full7920.exe'
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
