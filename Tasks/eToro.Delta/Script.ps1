$Object1 = Invoke-RestMethod -Uri 'https://download.todesktop.com/230821hmyd974o7/td-latest.json'

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  # InstallerUrl  = $Object1.artifacts.nsis.x64.url | ConvertTo-UnescapedUri
  InstallerUrl  = "https://updates.desktop.delta.app/versions/$($this.CurrentState.Version)/windows/nsis/x64"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'nullsoft'
  # InstallerUrl  = $Object1.artifacts.nsis.arm64.url | ConvertTo-UnescapedUri
  InstallerUrl  = "https://updates.desktop.delta.app/versions/$($this.CurrentState.Version)/windows/nsis/arm64"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.createdAt.ToUniversalTime()
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
