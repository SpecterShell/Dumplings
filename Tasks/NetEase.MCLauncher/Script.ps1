$Object = ("{$(Invoke-RestMethod -Uri 'https://x19.update.netease.com/pl/x19_java_patchlist')}" | ConvertFrom-Json -AsHashtable).GetEnumerator() |
  Where-Object -FilterScript { $_.Value.url.Contains('.exe') } |
  Select-Object -Last 1

# Version
$Task.CurrentState.Version = $Object[0].Name

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://x19.gdl.netease.com/MCLauncher_publish_$($Task.CurrentState.Version).exe"
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
