$Object1 = Invoke-RestMethod -Uri 'https://apps.ctrlprint.net/apps/transfermanager/appcast.xml'

# Version
$this.CurrentState.Version = $Object1.enclosure.Where({ try { $_.os -eq 'windows' } catch {} }, 'First')[0].version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.enclosure.Where({ try { $_.os -eq 'windows' } catch {} }, 'First')[0].url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.pubDate | Get-Date -AsUTC
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
