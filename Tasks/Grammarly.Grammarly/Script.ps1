$Object1 = Invoke-RestMethod -Uri 'https://update-windows.grammarly.com/update' -Method Post -Body (
  @{
    currentVersion = $this.LastState.Version ?? '1.0.16.275'
  } | ConvertTo-Json -Compress
)

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.download
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.releaseDate.ToUniversalTime()

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Write()
  }
  'Changed|Updated' {
    $this.Print()
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
