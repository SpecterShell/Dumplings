$DownloadUrl = Use-EdgeDriver -Headless {
  param($EdgeDriver)
  $EdgeDriver.Navigate().GoToUrl('https://www.thebrain.com/download')
  $EdgeDriver.FindElement([OpenQA.Selenium.By]::XPath('//a[contains(.//span, "Download")]')).GetAttribute('href')
}

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl -Uri $DownloadUrl -TimeoutSec 30 | ConvertTo-UnescapedUri
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
