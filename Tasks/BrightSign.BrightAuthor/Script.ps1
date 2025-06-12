$Object1 = Invoke-RestMethod -Uri 'https://brightsign-builds.s3.us-east-1.amazonaws.com/web/bs-download-versions.json'

# Version
$this.CurrentState.Version = $Object1.general.bac.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.general.bac.link
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.general.bac.'release-date' | Get-Date -Format 'yyyy-MM-dd'

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $Object1.general.bac.'release-notes'
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $EdgeDriver = Get-EdgeDriver -Headless
      $EdgeDriver.Navigate().GoToUrl('https://docs.brightsign.biz/releases/50')

      $ReleaseNotesObject = [OpenQA.Selenium.Support.UI.WebDriverWait]::new($EdgeDriver, [timespan]::FromSeconds(30)).Until(
        [System.Func[OpenQA.Selenium.IWebDriver, OpenQA.Selenium.IWebElement]] {
          param([OpenQA.Selenium.IWebDriver]$WebDriver)
          try { $WebDriver.FindElement([OpenQA.Selenium.By]::XPath('//div[@id="STRIPE_TEMPLATE_EDITOR"]')) } catch {}
        }
      ).GetAttribute('innerHTML') | ConvertFrom-Html
      $ReleaseNotesTitleNode = $ReleaseNotesObject.SelectSingleNode("//div[contains(@class, 'slate-h1') and contains(.//h1, '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and -not $Node.HasClass('slate-h1'); $Node = $Node.NextSibling) {
          if (-not $Node.InnerText.Contains('Download:')) {
            $Node
          }
        }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
