$Object1 = Invoke-RestMethod -Uri 'https://www.oculus.com/sparkle-updates/1582076955407037/'

# Version
$this.CurrentState.Version = $Object1.enclosure.version

# Installer
$InstallerUrlBuilder = [System.UriBuilder]::new($Object1.enclosure.url)
$InstallerUrlBuilder.Host = 'securecdn.oculus.com'
$InstallerUrlBuilder.Query = $InstallerUrlBuilder.Query -replace '&?fcl=[^&]+'
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrlBuilder.ToString().Replace(':443', '')
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.pubDate | Get-Date -AsUTC
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = ($InstallerFile | Read-ProductVersionFromExe).Split('.')[0..2] -join '.'

    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
    $this.Submit()
  }
}
