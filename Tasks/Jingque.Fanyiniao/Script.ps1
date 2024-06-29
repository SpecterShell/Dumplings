$EdgeDriver = Get-EdgeDriver
$EdgeDriver.Navigate().GoToUrl('https://www.fanyiniao.com/')

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $EdgeDriver.FindElement([OpenQA.Selenium.By]::XPath('//a[contains(@href, "win") and contains(@href, ".zip")]')).GetAttribute('href')
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '([\d\.]+)\.zip').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    $InstallerFileExtracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile '翻译鸟.exe' | Out-Host
    $InstallerFile2 = Join-Path $InstallerFileExtracted '翻译鸟.exe'

    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile2 | Read-ProductVersionFromExe
    # InstallerSha256
    $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash

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
