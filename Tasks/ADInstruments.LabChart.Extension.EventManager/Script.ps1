$Prefix = 'https://cdn.adinstruments.com/'

$Object1 = $Global:DumplingsStorage.ADInstrumentsApps.Where({ $_.ID -eq 'EventManager' }, 'First')[0]

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
      $Object2 = Invoke-WebRequest -Uri 'https://www.adinstruments.com/support/downloads/windows/event-manager' | ConvertFrom-Html

      if ($Object2.SelectSingleNode("//h1[@class='page-title']").InnerText -match "(\s|^)$([regex]::Escape($this.CurrentState.Version))(\s|$)") {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object2.SelectNodes('//div[@class="field__label" and contains(., "Release Notes")]/following-sibling::node()') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
