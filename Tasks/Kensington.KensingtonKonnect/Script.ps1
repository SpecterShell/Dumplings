$Prefix = 'https://www.kensington.com/software/kensington-konnect/'
$Object1 = curl -fsSLA $DumplingsInternetExplorerUserAgent $Prefix | Join-String -Separator "`n" | Get-EmbeddedLinks

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Prefix $Object1.Where({ try { $_.href.EndsWith('.msi') -and $_.href.Contains('kkbsetup') } catch {} }, 'First')[0].href
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $Prefix
      }

      $ReleaseNotesUrlLink = $Object1.Where({ try { $_.href.EndsWith('.pdf') -and $_.href.Contains('kensington-konnect') -and $_.href.Contains('release-notes') } catch {} }, 'First')
      if ($ReleaseNotesUrlLink) {
        # ReleaseNotesUrl (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = Join-Uri $Prefix $ReleaseNotesUrlLink[0].href
        }
      } else {
        $this.Log("No ReleaseNotesUrl (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromMsi

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
