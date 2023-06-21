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
