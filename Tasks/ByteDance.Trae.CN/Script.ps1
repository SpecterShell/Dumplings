$Object1 = Invoke-RestMethod -Uri 'https://api.trae.ai/icube/api/v1/native/version/trae/cn/latest'
# $Object1 = Invoke-RestMethod -Uri 'https://api.marscode.cn/icube/api/v1/native/version/trae/cn/latest'

# Version
$this.CurrentState.Version = $Object1.data.manifest.win32.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.manifest.win32.download.Where({ $_.region -eq 'va' }, 'First')[0].x64 | ConvertTo-UnescapedUri
}
# $this.CurrentState.Installer += [ordered]@{
#   InstallerUrl = $Object1.data.manifest.win32.download.Where({ $_.region -eq 'sg' }, 'First')[0].x64 | ConvertTo-UnescapedUri
# }
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  InstallerUrl    = $Object1.data.manifest.win32.download.Where({ $_.region -eq 'cn' }, 'First')[0].x64 | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.data.manifest.win32.extra.uploadDate | ConvertFrom-UnixTimeMilliseconds
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

    try {
      $EdgeDriver = Get-EdgeDriver -Headless
      $EdgeDriver.Navigate().GoToUrl('https://www.trae.cn/changelog')

      $ReleaseNotesNode = [OpenQA.Selenium.Support.UI.WebDriverWait]::new($EdgeDriver, [timespan]::FromSeconds(30)).Until(
        [System.Func[OpenQA.Selenium.IWebDriver, OpenQA.Selenium.IWebElement]] {
          param([OpenQA.Selenium.IWebDriver]$WebDriver)
          try { $WebDriver.FindElement([OpenQA.Selenium.By]::XPath("//section[contains(@class, 'versionEntry') and contains(.//div[contains(@class, 'metadataColumn')], '$($this.CurrentState.RealVersion)')]")) } catch {}
        }
      ).GetAttribute('innerHTML') | ConvertFrom-Html

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotesNode.SelectSingleNode('.//div[contains(@class, "contentColumn")]') | Get-TextContent | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
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
