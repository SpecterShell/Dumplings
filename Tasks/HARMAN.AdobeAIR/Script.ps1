$WebData = Use-PlaywrightPage -Stealth -Headless {
  param($Page)
  $null = Open-PlaywrightPage -Page $Page -Uri 'https://airsdk.harman.com/runtime'
  [pscustomobject]@{
    Version = [regex]::Match(
      (Read-PlaywrightLocator -Page $Page -Selector 'xpath=//div[contains(@class, "miniTitle") and contains(text(), "version")]' -Property InnerText),
      '(\d+(?:\.\d+){3,})'
    ).Groups[1].Value
    InstallerUrl = Read-PlaywrightLocator -Page $Page -Selector 'xpath=//a[contains(@class, "downloadLink") and contains(@href, ".exe")]' -Property Attribute -AttributeName href
  }
}

# Version
$this.CurrentState.Version = $WebData.Version

# Installer
$this.CurrentState.Installer += [ordered]@{ InstallerUrl = $WebData.InstallerUrl }

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
