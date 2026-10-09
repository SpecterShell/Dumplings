$Object1 = Invoke-WebRequest -Uri 'https://www.cherry.de/en-us/products/software-services/cherry-utility'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href.Contains('Utility_Software') } catch {} }, 'First')[0].href
  # InstallerUrl = "https://swrepo.data.cherry-world.com/sw/$($this.CurrentState.Version.Replace('.','_'))/win/x86/Cherry_Utility_Software.exe"
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, 'x32-([\d.]+)\.exe').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $Object1.Links.Where({ try { $_.href.EndsWith('-ReleaseNotes.pdf') -and $_.href.Contains('Utility') } catch {} }, 'First')[0].href
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = (Invoke-RestMethod -Uri 'https://swrepo.data.cherry-world.com/updates_v2.json').Where({ $_.updateType -eq 'sw' }, 'First')[0].releases.Where({ $_.architecture -eq 'x86' -and $_.os -eq 'win' -and $_.version -eq $this.CurrentState.Version }, 'Last')

      if ($Object2) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $Object2[0].timestamp | Get-Date -AsUTC

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object2[0].shortDescription | ConvertFrom-Html | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
