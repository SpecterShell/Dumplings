$WebData = Use-PlaywrightPage -Stealth -Headless {
  param($Page)
  $null = Open-PlaywrightPage -Page $Page -Uri 'https://www.huaweicloud.com/product/ideahub/ideashare.html'
  $Data = Invoke-PlaywrightJavaScript -Page $Page -Expression '() => ({ Version: versionDict.windowVersion, InstallerUrl: windowsUrl })'
  $Data.Version = [regex]::Match($Data.Version, '(\d+(?:\.\d+)+)').Groups[1].Value
  $Data
}

# Version
$this.CurrentState.Version = $WebData.Version

# Installer
$this.CurrentState.Installer += [ordered]@{ InstallerUrl = $WebData.InstallerUrl }

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
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
