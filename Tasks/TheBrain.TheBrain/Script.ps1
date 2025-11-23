$EdgeDriver = Get-EdgeDriver -Headless
$EdgeDriver.Navigate().GoToUrl('https://www.thebrain.com/download')

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl -Uri $EdgeDriver.FindElement([OpenQA.Selenium.By]::XPath('//a[contains(., "Download for Windows")]')).GetAttribute('href') -TimeoutSec 30 | ConvertTo-UnescapedUri
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

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
