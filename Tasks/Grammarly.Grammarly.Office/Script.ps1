$Object1 = Invoke-RestMethod -Uri 'https://update-officeaddin.grammarly.com/update' -Method Post -Body (
  @{
    currentVersion = $this.LastState.Version ?? '6.8.263'
  } | ConvertTo-Json -Compress
)

# Version
$this.CurrentState.Version = $Object1.version -join '.'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.installerUrl
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.releaseDate.ToUniversalTime()

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
