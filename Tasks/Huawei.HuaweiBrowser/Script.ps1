$EdgeDriver = Get-EdgeDriver
$EdgeDriver.Navigate().GoToUrl('https://consumer.huawei.com/cn/mobileservices/browser/')

# Installer
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrl1 = $EdgeDriver.FindElement([OpenQA.Selenium.By]::XPath('//a[./text()="PC for X64"]')).GetAttribute('href')
}

$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = $InstallerUrl2 = $EdgeDriver.FindElement([OpenQA.Selenium.By]::XPath('//a[./text()="PC for ARM"]')).GetAttribute('href')
}

# Version
$Task.CurrentState.Version = $Version1 = [regex]::Match($InstallerUrl1, 'HuaweiBrowser-([\d\.]+)').Groups[1].Value
$Version2 = [regex]::Match($InstallerUrl2, 'HuaweiBrowser-([\d\.]+)').Groups[1].Value

if ($Version1 -ne $Version2) {
  Write-Host -Object "Task $($Task.Name): Distinct versions detected" -ForegroundColor Yellow
  $Task.Config.Notes = '检测到不同的版本'
}

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
