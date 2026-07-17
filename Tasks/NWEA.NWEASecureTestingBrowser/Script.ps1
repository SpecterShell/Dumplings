$InstallerUrl = Use-EdgeDriver -Headless {
  param($EdgeDriver)
  $EdgeDriver.Navigate().GoToUrl('https://connection.nwea.org/s/technical-resources')
  [OpenQA.Selenium.Support.UI.WebDriverWait]::new($EdgeDriver, [timespan]::FromSeconds(30)).Until(
    [System.Func[OpenQA.Selenium.IWebDriver, OpenQA.Selenium.IWebElement]] {
      param([OpenQA.Selenium.IWebDriver]$WebDriver)
      try { $WebDriver.FindElement([OpenQA.Selenium.By]::XPath('//a[contains(@href, ".exe") and contains(@href, "Setup_Lockdown_Browser")]')) } catch {}
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
