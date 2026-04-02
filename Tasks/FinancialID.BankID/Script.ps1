# For some reasons, the installer URL can only be obtained when the web driver is not headless.
$EdgeDriver = New-EdgeDriver
try {
  $EdgeDriver.Navigate().GoToUrl('https://www.bankid.com/en/business/enterprise')

  # Installer
  $this.CurrentState.Installer += [ordered]@{
    InstallerUrl = [OpenQA.Selenium.Support.UI.WebDriverWait]::new($EdgeDriver, [timespan]::FromSeconds(30)).Until(
      [System.Func[OpenQA.Selenium.IWebDriver, OpenQA.Selenium.IWebElement]] {
        param([OpenQA.Selenium.IWebDriver]$WebDriver)
        try { $WebDriver.FindElement([OpenQA.Selenium.By]::CssSelector('a[href$=".zip"]')) } catch {}
      }
    ).GetAttribute('href').Trim()
  }
} finally {
  $EdgeDriver.Dispose()
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:_\d+)+)').Groups[1].Value.Replace('_', '.')

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    $InstallerFileExtracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile 'BankID.msi' | Out-Host
    $InstallerFile2 = Join-Path $InstallerFileExtracted 'BankID.msi'
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile2 | Read-ProductVersionFromMsi
    # ProductCode
    $this.CurrentState.Installer[0]['ProductCode'] = $InstallerFile2 | Read-ProductCodeFromMsi
    # AppsAndFeaturesEntries
    $this.CurrentState.Installer[0]['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        UpgradeCode = $InstallerFile2 | Read-UpgradeCodeFromMsi
      }
    )
    Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'

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
