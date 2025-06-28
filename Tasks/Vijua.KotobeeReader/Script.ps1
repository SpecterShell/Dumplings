$Object1 = Invoke-RestMethod -Uri 'https://files.kotobee.com/reader/releases/releases.json'

# Version
$this.CurrentState.Version = $Object1.latest

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://files.kotobee.com/reader/releases/kotobeereader-$($this.CurrentState.Version)-win.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object1.releases.Where({ try { $_.version -eq $this.CurrentState.Version } catch {} }, 'First')[0].description | Format-Text
      }
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
