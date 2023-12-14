$EdgeDriver = Get-EdgeDriver
$EdgeDriver.Navigate().GoToUrl('https://www.ixigua.com/app/')
Start-Sleep -Seconds 10

# Installer
$InstallerUrl = $EdgeDriver.FindElement([OpenQA.Selenium.By]::XPath('//*[@id="App"]/div/main/div/div[1]/div[1]/div[3]/a')).GetAttribute('href')
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl
}

# Version
$Task.CurrentState.Version = [regex]::Match($InstallerUrl, 'xigua-video-([\d\.]+)-default').Groups[1].Value

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 }) {
    $Task.Submit()
  }
}
