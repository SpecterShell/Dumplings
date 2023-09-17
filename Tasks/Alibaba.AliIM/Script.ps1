$EdgeDriver = Get-EdgeDriver
$EdgeDriver.Navigate().GoToUrl('https://market.m.taobao.com/app/im/ww-home/index.html')

$Button1 = $EdgeDriver.FindElement([OpenQA.Selenium.By]::XPath('//*[@id="root"]/div/div[1]/div[2]/div[2]'))
[OpenQA.Selenium.Interactions.Actions]::new($EdgeDriver).MoveToElement($Button1).Build().Perform()

# Installer
$InstallerUrl = $EdgeDriver.FindElement([OpenQA.Selenium.By]::XPath("//*[@id='root']/div/div[1]/div[2]/div[2]/div/div/div/a[1]")).GetAttribute('href')
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl
}

# Version
$Task.CurrentState.Version = [regex]::Match($InstallerUrl, '\((.+)\)\.exe').Groups[1].Value

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
