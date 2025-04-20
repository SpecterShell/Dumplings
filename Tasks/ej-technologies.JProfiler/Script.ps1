$Prefix = 'https://download.ej-technologies.com/jprofiler/'
$Object1 = (Invoke-RestMethod -Uri "${Prefix}updates15.xml").updateDescriptor.entry.Where({ $_.targetMediaFileId -eq '223' }, 'First')[0]

# Version
$this.CurrentState.Version = $Object1.newVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Prefix $Object1.fileName
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = (Invoke-RestMethod -Uri 'https://www.ej-technologies.com/feeds/jprofiler').Where({ $_.title.Contains($this.CurrentState.Version) }, 'First')

      if ($Object2) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $Object2[0].pubDate | Get-Date -AsUTC

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object2[0].description | ConvertFrom-Html | Get-TextContent | Format-Text
        }

        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $Object2[0].link
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
