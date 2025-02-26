$EdgeDriver = Get-EdgeDriver -Headless
$EdgeDriver.Navigate().GoToUrl('https://effidit.qq.com/')

$EdgeDriver.FindElement([OpenQA.Selenium.By]::XPath('//p[@class="down"]')).Click()
$EdgeDriver.FindElement([OpenQA.Selenium.By]::XPath('//div[contains(@class, "lag-k") and (text()="英文" or text()="EN")]')).Click()

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $EdgeDriver.FindElement([OpenQA.Selenium.By]::XPath('//a[contains(@href, ".msi")]')).GetAttribute('href')
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, 'v([\d\.]+)').Groups[1].Value

$EdgeDriver.FindElement([OpenQA.Selenium.By]::XPath('//div[contains(@class, "lag-k") and (text()="中文" or text()="ZH")]')).Click()

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  InstallerUrl    = $InstallerUrl = $EdgeDriver.FindElement([OpenQA.Selenium.By]::XPath('//a[contains(@href, ".msi")]')).GetAttribute('href')
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
