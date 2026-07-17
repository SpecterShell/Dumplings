$InstallerUrl = Use-EdgeDriver -Headless {
  param($EdgeDriver)
  $EdgeDriver.Navigate().GoToUrl('https://klant.afas.nl/update-center/downloads')
  [OpenQA.Selenium.Support.UI.WebDriverWait]::new($EdgeDriver, [timespan]::FromSeconds(30)).Until(
    [System.Func[OpenQA.Selenium.IWebDriver, OpenQA.Selenium.IWebElement]] {
      param([OpenQA.Selenium.IWebDriver]$WebDriver)
      try { $WebDriver.FindElement([OpenQA.Selenium.By]::XPath('//a[contains(@href, ".exe") and contains(@href, "PccSetup7")]')) } catch {}
    }
  ).GetAttribute('href')
}

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    foreach ($Installer in $this.CurrentState.Installer) {
      $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
      $InstallerInfo = Get-InstallShieldMsiInfo -Path $InstallerFile -Name 'Profit Communication Center.msi'
      # RealVersion
      $this.CurrentState.RealVersion = $InstallerInfo.ProductVersion
    }

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
