$WebData = Use-EdgeDriver -Headless {
  param($EdgeDriver)
  $EdgeDriver.Navigate().GoToUrl('https://www.huaweicloud.com/product/ideahub/ideashare.html')
  Start-Sleep -Seconds 3
  [pscustomobject]@{
    Version      = [regex]::Match($EdgeDriver.ExecuteScript('return versionDict.opsVersion'), '(\d+(?:\.\d+)+)').Groups[1].Value
    InstallerUrl = $EdgeDriver.ExecuteScript('return opsUrl')
  }
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
