$Object = Invoke-RestMethod -Uri 'https://update-windows.grammarly.com/update' -Method Post -Body (
  @{
    currentVersion = $Task.LastState.Version ?? '1.0.16.275'
  } | ConvertTo-Json -Compress
)

# Version
$Task.CurrentState.Version = $Object.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.download
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object.releaseDate.ToUniversalTime()

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
