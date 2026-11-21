$Object1 = Invoke-RestMethod -Uri 'https://ulaa.com/release/win/release-manifest.json'

# Version
$this.CurrentState.Version = $Object1.releases[-1].chromiumVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.releases[-1].url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.releases[-1].release_timestamp | ConvertFrom-UnixTimeSeconds
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
