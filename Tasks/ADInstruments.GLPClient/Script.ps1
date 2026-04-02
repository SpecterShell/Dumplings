$Object1 = Invoke-WebRequest -Uri 'https://www.adinstruments.com/support/downloads/windows/glp-client' -UserAgent $DumplingsBrowserUserAgent

# Version
$this.CurrentState.Version = [regex]::Match($Object1.Content, 'GLP Client (\d+(\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl -Uri $Object1.Links.Where({ try { $_.href.EndsWith('.msi') } catch {} }, 'First')[0].href
  Dependencies = @(
    [ordered]@{
      PackageIdentifier = 'ADInstruments.LabChart'
      MinimumVersion    = $this.CurrentState.Version.Split('.')[0..1] -join '.'
    }
  )
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $Object1.Links.Where({ try { $_.href.EndsWith('.pdf') -and $_.href.Contains('ReleaseNotes') } catch {} }, 'First')[0].href | ConvertTo-Https
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
