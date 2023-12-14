$Task.CurrentState = Invoke-WondershareXmlDownloadApi -ProductId 5373

# Version
$Task.CurrentState.Version = [regex]::Match($Task.CurrentState.Version, '(\d+\.\d+)').Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://download.edrawsoft.com/cbs_down/orgchartcreator_full5373.exe'
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
