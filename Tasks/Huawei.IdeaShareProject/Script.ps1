$EdgeDriver = Get-EdgeDriver -Headless
$EdgeDriver.Navigate().GoToUrl('https://www.huaweicloud.com/product/ideahub/ideashare.html')
Start-Sleep -Seconds 3

# Version
$this.CurrentState.Version = [regex]::Match($EdgeDriver.ExecuteScript('return versionDict.opsVersion'), '(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $EdgeDriver.ExecuteScript('return opsUrl')
}

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
