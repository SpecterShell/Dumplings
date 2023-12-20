$EdgeDriver = Get-EdgeDriver
$EdgeDriver.Navigate().GoToUrl('https://www.cocos.com/creator-download')

$Object = $EdgeDriver.ExecuteScript('return window.__NUXT__.data[0].dashboardLatest', $null)

# Version
$this.CurrentState.Version = $Object.version

# Installer
$this.CurrentState.Installer += $Installer = [ordered]@{
  InstallerUrl = $Object.win32_url
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object.publish_time | ConvertFrom-UnixTimeSeconds

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl

    # InstallerSha256
    $Installer['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
