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

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.releaseDate.ToUniversalTime()
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
