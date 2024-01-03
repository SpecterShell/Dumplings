$EdgeDriver = Get-EdgeDriver
$EdgeDriver.Navigate().GoToUrl('https://consumer.huawei.com/cn/mobileservices/browser/')
Start-Sleep -Seconds 5

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrlX64 = $EdgeDriver.FindElement([OpenQA.Selenium.By]::XPath('//a[./text()="PC for X64"]')).GetAttribute('href')
}
$VersionX64 = [regex]::Match($InstallerUrlX64, 'HuaweiBrowser-([\d\.]+)').Groups[1].Value

$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = $InstallerUrlX86 = $EdgeDriver.FindElement([OpenQA.Selenium.By]::XPath('//a[./text()="PC for ARM"]')).GetAttribute('href')
}
$VersionX86 = [regex]::Match($InstallerUrlX86, 'HuaweiBrowser-([\d\.]+)').Groups[1].Value

$Identical = $true
if ($VersionX64 -ne $VersionX86) {
  $this.Logging('Distinct versions detected', 'Warning')
  $Identical = $false
}

# Version
$this.CurrentState.Version = $VersionX64

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
