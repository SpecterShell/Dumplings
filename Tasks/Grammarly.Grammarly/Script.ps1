$Object = Invoke-RestMethod -Uri 'https://update-windows.grammarly.com/update' -Method Post -Body (
  @{
    currentVersion = $this.LastState.Version ?? '1.0.16.275'
  } | ConvertTo-Json -Compress
)

# Version
$this.CurrentState.Version = $Object.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.download
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object.releaseDate.ToUniversalTime()

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
