$Object1 = Invoke-RestMethod -Uri 'https://dist.scaleft.com/repos/windows/stable/amd64/windows-client/dull.json'

# Version
$this.CurrentState.Version = $Object1.releases[0].version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://dist.scaleft.com/repos/windows/stable/amd64/windows-client/$($Object1.releases[0].links[0].href)"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.releases[0].date.ToUniversalTime()
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
