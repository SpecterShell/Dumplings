$EdgeDriver = Get-EdgeDriver
$EdgeDriver.Navigate().GoToUrl('https://consumer.huawei.com/cn/mobileservices/browser/')
Start-Sleep -Seconds 5

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrl1 = $EdgeDriver.FindElement([OpenQA.Selenium.By]::XPath('//a[./text()="PC for X64"]')).GetAttribute('href')
}

$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = $InstallerUrl2 = $EdgeDriver.FindElement([OpenQA.Selenium.By]::XPath('//a[./text()="PC for ARM"]')).GetAttribute('href')
}

# Version
$this.CurrentState.Version = $Version1 = [regex]::Match($InstallerUrl1, 'HuaweiBrowser-([\d\.]+)').Groups[1].Value
$Version2 = [regex]::Match($InstallerUrl2, 'HuaweiBrowser-([\d\.]+)').Groups[1].Value

$Identical = $true
if ($Version1 -ne $Version2) {
  $this.Logging('Distinct versions detected', 'Warning')
  $Identical = $false
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 -and $Identical }) {
    $this.Submit()
  }
}
