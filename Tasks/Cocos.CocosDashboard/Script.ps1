$EdgeDriver = Get-EdgeDriver
$EdgeDriver.Navigate().GoToUrl('https://www.cocos.com/creator-download')

$Object1 = $EdgeDriver.ExecuteScript('return window.__NUXT__.data[0].dashboardLatest', $null)

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += $Installer = [ordered]@{
  InstallerUrl = $Object1.win32_url
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.publish_time | ConvertFrom-UnixTimeSeconds

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl

    # InstallerSha256
    $Installer['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

    $this.Write()
  }
  'Changed|Updated' {
    $this.Print()
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
