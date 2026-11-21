$Object1 = Invoke-RestMethod -Uri 'https://open.lkcoffee.com/cli/manifest.json'

# Version
$this.CurrentState.Version = $Object1.latest

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.files.Where({ $_.os -eq 'windows' -and $_.arch -eq 'amd64' }, 'First')[0].url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = $Object1.files.Where({ $_.os -eq 'windows' -and $_.arch -eq 'arm64' }, 'First')[0].url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()
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
