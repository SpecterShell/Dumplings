$Object1 = Invoke-RestMethod -Uri 'https://www.wind.com.cn/windftp/version.xml'

# Version
$this.CurrentState.Version = $Object1.WFTVersionDate.WFTWin.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'en-US'
  InstallerUrl    = $Object1.WFTVersionDate.WFTWin.ENUURL
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  InstallerUrl    = $Object1.WFTVersionDate.WFTWin.CHSURL
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
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
