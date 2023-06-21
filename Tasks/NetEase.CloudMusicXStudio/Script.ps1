$EdgeDriver.Navigate().GoToUrl('https://xstudio.music.163.com/')

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $EdgeDriver.FindElement([OpenQA.Selenium.By]::XPath('//*[@id="page_one"]/div/p[4]/a')).GetAttribute('href') | ConvertTo-UnescapedUri
}

# Version
$Task.CurrentState.Version = [regex]::Match($InstallerUrl, 'XStudio_([\d\.]+)').Groups[1].Value

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    # RealVersion
    $Task.CurrentState.RealVersion = Get-TempFile -Uri $InstallerUrl | Read-ProductVersionFromExe

    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
