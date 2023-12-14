$Object = Invoke-RestMethod -Uri 'https://update-officeaddin.grammarly.com/update' -Method Post -Body (
  @{
    currentVersion = $Task.LastState.Version ?? '6.8.263'
  } | ConvertTo-Json -Compress
)

# Version
$Task.CurrentState.Version = $Object.version -join '.'

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.installerUrl
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
