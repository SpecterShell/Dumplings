$InstallerUrl = Use-EdgeDriver -Headless {
  param($EdgeDriver)
  $EdgeDriver.Navigate().GoToUrl('https://market.m.taobao.com/app/im/ww-home/index.html')
  $Button = $EdgeDriver.FindElement([OpenQA.Selenium.By]::XPath('//span[@class="newVersion"]'))
  [OpenQA.Selenium.Interactions.Actions]::new($EdgeDriver).MoveToElement($Button).Build().Perform()
  $EdgeDriver.FindElement([OpenQA.Selenium.By]::XPath("//a[@class='windowVersions']")).GetAttribute('href')
}

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '\((\d+\.\d+\.\d+[A-Za-z]*)\)').Groups[1].Value

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
