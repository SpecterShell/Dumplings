$EdgeDriver = Get-EdgeDriver -Headless
$EdgeDriver.Navigate().GoToUrl('https://connection.nwea.org/s/technical-resources')

$Object1 = [OpenQA.Selenium.Support.UI.WebDriverWait]::new($EdgeDriver, [timespan]::FromSeconds(30)).Until(
  [System.Func[OpenQA.Selenium.IWebDriver, OpenQA.Selenium.IWebElement]] {
    param([OpenQA.Selenium.IWebDriver]$WebDriver)
    try { $WebDriver.FindElement([OpenQA.Selenium.By]::XPath('//a[contains(@href, ".exe") and contains(@href, "Setup_Lockdown_Browser")]')) } catch {}
  }
)

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.GetAttribute('href')
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
