$Object1 = Invoke-RestMethod -Uri 'https://prod.download.desktop.kiro.dev/stable/metadata-win32-x64-user-stable.json'

# Version
$this.CurrentState.Version = $Object1.currentRelease

$Object2 = $Object1.releases.Where({ $_.updateTo.version -eq $this.CurrentState.Version }, 'First')[0]

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  Scope        = 'user'
  InstallerUrl = $Object2.updateTo.url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.updateTo.pub_date | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl = 'https://kiro.dev/changelog/ide/'
      }

      $EdgeDriver = Get-EdgeDriver -Headless
      $EdgeDriver.Navigate().GoToUrl($ReleaseNotesUrl)
      $ReleaseNotesNode = [OpenQA.Selenium.Support.UI.WebDriverWait]::new($EdgeDriver, [timespan]::FromSeconds(30)).Until(
        [System.Func[OpenQA.Selenium.IWebDriver, OpenQA.Selenium.IWebElement]] {
          param([OpenQA.Selenium.IWebDriver]$WebDriver)
          try { $WebDriver.FindElement([OpenQA.Selenium.By]::XPath("//div[contains(./div[1]/div/div/span[2], 'IDE') and (contains(./div[1]/div/div/span[1], '$($this.CurrentState.Version -replace '(\.0+)+$')') or contains(./div[1]/div/div/span[1], '$('{0}.{1}' -f $this.CurrentState.Version.Split('.'))'))]")) } catch {}
        }
      )
      try { $ReleaseNotesNode.FindElements([OpenQA.Selenium.By]::XPath('.//button[@data-state="closed"]')).ForEach({ $_.Click() }) } catch {}
      $ReleaseNotesObject = $ReleaseNotesNode.GetAttribute('innerHTML') | ConvertFrom-Html

      if ($ReleaseNotesObject) {
        # Remove "Learn more" links
        $ReleaseNotesObject.SelectNodes('.//a[contains(text(), "Learn more")]').ForEach({ $_.Remove() })
        # Remove anchor links
        $ReleaseNotesObject.SelectNodes('.//a[@class="anchor-link"]').ForEach({ $_.Remove() })
        # Remove "Video unavailable"
        $ReleaseNotesObject.SelectNodes('./*/div[contains(., "Video unavailable")]').ForEach({ $_.Remove() })
        # Remove figures
        $ReleaseNotesObject.SelectNodes('./*/div[figure]').ForEach({ $_.Remove() })
        # Remove buttons
        $ReleaseNotesObject.SelectNodes('.//button[@data-state="open" and count(*)>1]/div[last()]').ForEach({ $_.Remove() })
        $ReleaseNotesObject.SelectNodes('.//div[count(*)=1 and contains(./button/@aria-label, "Copy command")]').ForEach({ $_.Remove() })
        # Remove empty p
        $ReleaseNotesObject.SelectNodes('.//p[not(*) and not(normalize-space())]').ForEach({ $_.Remove() })
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObject.SelectNodes('./div[1]/following-sibling::node()') | Get-TextContent | Format-Text
        }
        # ReleaseNotesUrl (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = $ReleaseNotesUrl = Join-Uri $ReleaseNotesUrl $ReleaseNotesObject.SelectSingleNode('.//a[./h2]').Attributes['href'].Value
        }

        $EdgeDriver.Navigate().GoToUrl($ReleaseNotesUrl)
        $ReleaseNotesObject = [OpenQA.Selenium.Support.UI.WebDriverWait]::new($EdgeDriver, [timespan]::FromSeconds(30)).Until(
          [System.Func[OpenQA.Selenium.IWebDriver, OpenQA.Selenium.IWebElement]] {
            param([OpenQA.Selenium.IWebDriver]$WebDriver)
            try { $WebDriver.FindElement([OpenQA.Selenium.By]::XPath('//article//*[@id="patches"]//button[@data-state="closed"]')) } catch {}
          }
        )
        $ReleaseNotesObject.Click()
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObject.FindElement([OpenQA.Selenium.By]::XPath("//*[contains(@id, 'patch-$($this.CurrentState.Version.Replace('.', '-'))')]/p/following-sibling::node()")).GetAttribute('innerHTML') | ConvertFrom-Html | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
