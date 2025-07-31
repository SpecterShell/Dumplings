$Object1 = Invoke-WebRequest -Uri 'https://my.lancom-systems.com/downloads/'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.Links.Where({ try { $_.href.Contains('Wireless-ePaper-Server') -and $_.href.EndsWith('.exe') } catch {} }, 'First')[0].href
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

# RealVersion
$this.CurrentState.RealVersion = $this.CurrentState.Version -replace '(?<=^|\.)0+'

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $Object1.Links.Where({ try { $_.href.EndsWith('.pdf') -and $_.href.Contains('RN') -and $_.href.Contains('Wireless-ePaper-Server') } catch {} }, 'First')[0].href
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
