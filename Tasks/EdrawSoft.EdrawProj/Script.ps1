$Task.CurrentState = Invoke-WondershareXmlDownloadApi -ProductId 5372

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://download.edrawsoft.com/cbs_down/edrawproject_full5372.exe'
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
