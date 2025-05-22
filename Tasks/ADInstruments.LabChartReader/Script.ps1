$MajorVersion = 8
if ((Invoke-WebRequest -Uri "https://www.adinstruments.com/LabChartReader$($MajorVersion + 1)SoftwareUpdateWin.plist" -MaximumRetryCount 0 -SkipHttpErrorCheck).StatusCode -eq 200) {
  $MajorVersion += 1
  $this.Log("Next major version ${MajorVersion} available", 'Warning')
}
$Object1 = Invoke-RestMethod -Uri "https://www.adinstruments.com/LabChartReader${MajorVersion}SoftwareUpdateWin.plist" | ConvertFrom-PropertyList
$Object2 = $Object1.Where({ $_.ID -eq 'LabChartReader' -and $_.LanguageID -eq '5129' }, 'First')[0]

# Version
$this.CurrentState.Version = $Object2.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri 'https://cdn.adinstruments.com/' $Object2.DownloadURL
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.'Release Date' | Get-Date -Format 'yyyy-MM-dd'
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
