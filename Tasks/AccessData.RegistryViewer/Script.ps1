$Object1 = Invoke-WebRequest -Uri ($Prefix = 'https://www.exterro.com/ftk-downloads')
$Object2 = Invoke-WebRequest -Uri ($Prefix = Join-Uri $Prefix $Object1.Links.Where({ try { $_.href.Contains('ftk-downloads/registry-viewer') } catch {} }, 'First')[0].href)

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object2.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href -match 'Registry_Viewer' } catch {} }, 'First')[0].href
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
        Value  = $Object2.Links.Where({ try { $_.href.EndsWith('.pdf') -and $_.href -match 'RegistryViewer' -and $_.href -match '_RN' } catch {} }, 'First')[0].href
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

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
