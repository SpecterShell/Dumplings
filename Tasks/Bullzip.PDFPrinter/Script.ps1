$Prefix = 'https://www.bullzip.com/products/pdf/download.php'

$EdgeDriver = Get-EdgeDriver -Headless
$EdgeDriver.Navigate().GoToUrl($Prefix)
Start-Sleep -Seconds 5
$Object1 = [OpenQA.Selenium.Support.UI.WebDriverWait]::new($EdgeDriver, [timespan]::FromSeconds(30)).Until(
  [System.Func[OpenQA.Selenium.IWebDriver, OpenQA.Selenium.IWebElement]] {
    param([OpenQA.Selenium.IWebDriver]$WebDriver)
    try { $WebDriver.FindElement([OpenQA.Selenium.By]::XPath('//a[contains(@href, ".exe") and contains(@href, "BullzipPDFPrinter")]')) } catch {}
  }
)

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Prefix $Object1.GetAttribute('href') | Split-Uri -LeftPart 'Path'
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:_\d+)+)').Groups[1].Value.Replace('_', '.')

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = 'https://www.bullzip.com/products/pdf/info.php'
      }

      $Object2 = $EdgeDriver.ExecuteScript('return await fetch("https://www.bullzip.com/products/pdf/rss.php").then(r => r.text())') | ConvertFrom-Xml
      $Object3 = $Object2.rss.channel.item.Where({ $_.title.Contains($this.CurrentState.Version) }, 'First')

      if ($Object3) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $Object3[0].pubDate | Get-Date -AsUTC

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object3[0].description | ConvertFrom-Html | Get-TextContent | Format-Text
        }

        # ReleaseNotesUrl (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = $Object3[0].link | ConvertTo-Https
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
