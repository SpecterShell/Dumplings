$EdgeDriver = Get-EdgeDriver -Headless
$EdgeDriver.Navigate().GoToUrl('https://klant.afas.nl/update-center/downloads')

$Object1 = [OpenQA.Selenium.Support.UI.WebDriverWait]::new($EdgeDriver, [timespan]::FromSeconds(30)).Until(
  [System.Func[OpenQA.Selenium.IWebDriver, OpenQA.Selenium.IWebElement]] {
    param([OpenQA.Selenium.IWebDriver]$WebDriver)
    try { $WebDriver.FindElement([OpenQA.Selenium.By]::XPath('//a[contains(@href, ".exe")]')) } catch {}
  }
)

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.GetAttribute('href')
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    foreach ($Installer in $this.CurrentState.Installer) {
      $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
      $InstallerFileExtracted = $InstallerFile | Expand-InstallShield
      $InstallerFile2 = Join-Path $InstallerFileExtracted 'Profit Communication Center.msi'
      # RealVersion
      $this.CurrentState.RealVersion = $InstallerFile2 | Read-ProductVersionFromMsi
      # ProductCode
      $Installer.ProductCode = $InstallerFile2 | Read-ProductCodeFromMsi
      # AppsAndFeaturesEntries
      $Installer.AppsAndFeaturesEntries = @(
        [ordered]@{
          UpgradeCode   = $InstallerFile2 | Read-UpgradeCodeFromMsi
          InstallerType = 'msi'
        }
      )
      Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
    }

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
