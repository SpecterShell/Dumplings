$Task.CurrentState = Invoke-WondershareXmlDownloadApi -ProductId 5372

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://download.edrawsoft.com/cbs_down/edrawproject_full5372.exe'
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
