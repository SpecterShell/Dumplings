$Task.CurrentState = Invoke-WondershareXmlDownloadApi -ProductId 839

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://download.wondershare.com/cbs_down/pdf-converter-pro_full839.exe'
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
