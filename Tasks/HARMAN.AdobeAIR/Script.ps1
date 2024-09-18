$EdgeDriver = Get-EdgeDriver -Headless
$EdgeDriver.Navigate().GoToUrl('https://airsdk.harman.com/runtime')

# Version
$this.CurrentState.Version = [regex]::Match(
  $EdgeDriver.FindElement([OpenQA.Selenium.By]::XPath('//div[contains(@class, "miniTitle") and contains(text(), "version")]')).Text,
  '(\d+(?:\.\d+){3,})'
).Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $EdgeDriver.FindElement([OpenQA.Selenium.By]::XPath('//a[contains(@class, "downloadLink") and contains(@href, ".exe")]')).GetAttribute('href')
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object3 = (Invoke-RestMethod -Uri 'https://airsdk.harman.com/api/versions/release-notes').Where({ $_.versionName -eq $this.CurrentState.Version })

      if ($Object3) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $Object3[0].releasedDate | ConvertFrom-UnixTimeMilliseconds

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object3[0].releaseNotes | ForEach-Object -Process { "$($_.title): $($_.description)" } | Format-Text
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
