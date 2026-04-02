# x64 user
$Object1 = Invoke-RestMethod -Uri 'https://catpaw.meituan.com/api/ide/update/api/update/win32-x64-user/stable/latest' -Headers @{
  'ide-version' = $this.Status.Contains('New') ? '2025.9.5' : $this.LastState.Version
  'ide-type'    = 'CatPaw'
  'tenant'      = '5282fa6645'
} -StatusCodeVariable 'StatusCode'

if ($StatusCode -eq 204) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

# Version
$this.CurrentState.Version = $Object1.productVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $EdgeDriver = Get-EdgeDriver -Headless
      $EdgeDriver.Navigate().GoToUrl('https://catpaw.meituan.com/changelog')
      $ReleaseNotesObject = [OpenQA.Selenium.Support.UI.WebDriverWait]::new($EdgeDriver, [timespan]::FromSeconds(30)).Until(
        [System.Func[OpenQA.Selenium.IWebDriver, OpenQA.Selenium.IWebElement]] {
          param([OpenQA.Selenium.IWebDriver]$WebDriver)
          try { $WebDriver.FindElement([OpenQA.Selenium.By]::XPath("//*[@class='timeline-item' and contains(.//*[@class='version-title'], '$($this.CurrentState.Version)')]")) } catch {}
        }
      ).GetAttribute('innerHTML') | ConvertFrom-Html

      if ($ReleaseNotesObject) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesObject.SelectSingleNode('.//*[@class="version-date"]').InnerText, '(20\d{2}年\d{1,2}月\d{1,2}日)').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObject.SelectNodes('.//*[@class="markdown-content"]') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
