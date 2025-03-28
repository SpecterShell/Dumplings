$EdgeDriver = Get-EdgeDriver -Headless
$EdgeDriver.Navigate().GoToUrl('https://www.ixigua.com/app/')

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = [OpenQA.Selenium.Support.UI.WebDriverWait]::new($EdgeDriver, [timespan]::FromSeconds(30)).Until(
    [System.Func[OpenQA.Selenium.IWebDriver, OpenQA.Selenium.IWebElement]] {
      param([OpenQA.Selenium.IWebDriver]$WebDriver)
      try { $WebDriver.FindElement([OpenQA.Selenium.By]::XPath('//div[contains(@class, "windows")]/a[@class="download__btn"]')) } catch {}
    }
  ).GetAttribute('href')
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '-(\d+\.\d+\.\d+)[-.]').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    $ToSubmit = $false

    $Mutex = [System.Threading.Mutex]::new($false, 'DumplingsSubmitLockXiguaVideo')
    $Mutex.WaitOne(30000) | Out-Null
    if (-not $Global:DumplingsStorage.Contains("XiguaVideo-$($this.CurrentState.Version)-ToSubmit")) {
      $Global:DumplingsStorage["XiguaVideo-$($this.CurrentState.Version)-ToSubmit"] = $ToSubmit = $true
    }
    $Mutex.ReleaseMutex()
    $Mutex.Dispose()

    if ($ToSubmit) {
      $this.Submit()
    } else {
      $this.Log('Another task is submitting manifests for this package', 'Warning')
    }
  }
}
