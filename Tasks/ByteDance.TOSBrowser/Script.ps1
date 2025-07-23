$Object1 = Invoke-RestMethod -Uri 'https://tron.jiyunhudong.com/api/sdk/check_update?pid=7122772962347849988&branch=master&buildId=&uid='

# Version
$this.CurrentState.Version = $Object1.data.manifest.win32.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.data.manifest.win32.urls.Where({ $_.region -eq 'sg' }, 'First')[0].path.ia32
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.data.manifest.win32.urls.Where({ $_.region -eq 'sg' }, 'First')[0].path.x64
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  Architecture    = 'x86'
  InstallerUrl    = $Object1.data.manifest.win32.urls.Where({ $_.region -eq 'cn' }, 'First')[0].path.ia32
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  Architecture    = 'x64'
  InstallerUrl    = $Object1.data.manifest.win32.urls.Where({ $_.region -eq 'cn' }, 'First')[0].path.x64
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

    try {
      $EdgeDriver = Get-EdgeDriver -Headless
      $EdgeDriver.Navigate().GoToUrl('https://www.volcengine.com/docs/6349/148777')

      $ReleaseNotesNode = [OpenQA.Selenium.Support.UI.WebDriverWait]::new($EdgeDriver, [timespan]::FromSeconds(30)).Until(
        [System.Func[OpenQA.Selenium.IWebDriver, OpenQA.Selenium.IWebElement]] {
          param([OpenQA.Selenium.IWebDriver]$WebDriver)
          try { $WebDriver.FindElement([OpenQA.Selenium.By]::XPath("//table/tbody/tr[contains(./td[1], '$($this.CurrentState.Version)')]")) } catch {}
        }
      ).GetAttribute('innerHTML') | ConvertFrom-Html
      if ($ReleaseNotesNode) {
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectSingleNode('./td[4]') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
