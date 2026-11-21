$Prefix = 'https://cdn.adinstruments.com/'

$Object1 = $Global:DumplingsStorage.ADInstrumentsApps.Where({ $_.ID -eq 'Metabolic' }, 'First')[0]

# Version
$this.CurrentState.Version = $Object1.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Prefix $Object1.DownloadURL
  Dependencies = [ordered]@{
    PackageDependencies = @(
      [ordered]@{
        PackageIdentifier = 'ADInstruments.LabChart'
        MinimumVersion    = $Object1.ChartVersion.ToString()
      }
    )
  }
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.'Release Date' | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromMsi

    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $null
      }

      $Object2 = Invoke-WebRequest -Uri 'https://www.adinstruments.com/support/downloads/windows/metabolic' | ConvertFrom-Html

      if ($Object2.SelectSingleNode("//h1[@class='page-title']").InnerText -match "(\s|^)$([regex]::Escape($this.CurrentState.Version))(\s|$)") {
        # ReleaseNotesUrl (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = $Object2.SelectSingleNode('//a[contains(., "Release Notes") and contains(@href, ".pdf")]').Attributes['href'].Value | ConvertTo-Https
        }
      } else {
        $this.Log("No ReleaseNotesUrl (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
