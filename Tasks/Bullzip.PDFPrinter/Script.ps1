$Prefix = 'https://www.bullzip.com/products/pdf/download.php'

$Object1 = Use-PlaywrightPage -Stealth -Headless {
  param($Page)

  $null = Open-PlaywrightPage -Page $Page -Uri $Prefix
  Read-PlaywrightLocator -Page $Page -Selector 'xpath=//a[contains(@href, ".exe") and contains(@href, "BullzipPDFPrinter")]' -Property Attribute -AttributeName href
}

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Prefix $Object1 | Split-Uri -LeftPart 'Path'
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

      $Object2 = Use-PlaywrightPage -Stealth -Headless {
        param($Page)

        $null = Open-PlaywrightPage -Page $Page -Uri $Prefix
        Invoke-PlaywrightJavaScript -Page $Page -Expression 'async () => await fetch("https://www.bullzip.com/products/pdf/rss.php").then((response) => response.text())'
      } | ConvertFrom-Xml
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
