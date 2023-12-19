$Object = Invoke-RestMethod -Uri 'https://update-officeaddin.grammarly.com/update' -Method Post -Body (
  @{
    currentVersion = $this.LastState.Version ?? '6.8.263'
  } | ConvertTo-Json -Compress
)

# Version
$this.CurrentState.Version = $Object.version -join '.'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.installerUrl
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
