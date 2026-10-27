$Object1 = Invoke-WebRequest -Uri 'https://blackboxframework.org/index.php?cID=goto-download-page,en-us'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'inno'
  InstallerUrl  = Join-Uri 'https://blackboxframework.org' $Object1.Links.Where({ $_.outerHTML -match 'Stable version (?<Version>\d+(?:\.\d+)+), Setup' }, 'First')[0].href
}

# Version
$this.CurrentState.Version = $Matches['Version']

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match($Object1.Content, 'release is Version \d+(?:\.\d+)+ \(Build \d+, (?<ReleaseDate>\d{1,2}-[A-Za-z]+-\d{4})\)').Groups['ReleaseDate'].Value | Get-Date -Format 'yyyy-MM-dd'

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl = Join-Uri 'https://blackboxframework.org' $Object1.Links.Where({ $_.href -eq "stable/blackbox-$($this.CurrentState.Version)-changes.html" }, 'First')[0].href
      }

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html | Get-TextContent | Format-Text
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
