$Task.CurrentState = Invoke-WondershareXmlDownloadApi -ProductId 5373

# Version
$Task.CurrentState.Version = [regex]::Match($Task.CurrentState.Version, '(\d+\.\d+)').Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://download.edrawsoft.com/cbs_down/orgchartcreator_full5373.exe'
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
