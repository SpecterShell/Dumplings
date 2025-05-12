$EdgeDriver = Get-EdgeDriver -Headless
$EdgeDriver.Navigate().GoToUrl('https://www.todesk.com/download.html')

$Object1 = $EdgeDriver.ExecuteScript('return window.__NUXT__.data[0].clientInfo', $null)

# Version
$this.CurrentState.Version = $Object1.win_version

try {
  $InstallerUrl = "https://dl.todesk.com/irrigation/ToDesk_$($this.CurrentState.Version).exe"
  Invoke-WebRequest -Uri $InstallerUrl -Method Head | Out-Null
  # Installer
  $this.CurrentState.Installer += [ordered]@{
    InstallerUrl = $InstallerUrl
  }
} catch {
  $this.Log("${InstallerUrl} doesn't exist, fallback to $($Object1.soft.https.'#cdata-section')", 'Warning')
  # Installer
  $this.CurrentState.Installer += [ordered]@{
    InstallerUrl = $Object1.SelectSingleNode('//div[@class="win_download"]').Attributes['href'].Value
  }
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://update.todesk.com/windows/uplog.html' | ConvertFrom-Html

      $ReleaseNotesNode = $Object2.SelectSingleNode("//div[@class='row' and contains(.//div[@class='text'], '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match(
          $ReleaseNotesNode.SelectSingleNode('.//div[@class="release-date"]').InnerText,
          '(\d{4}\.\d{1,2}\.\d{1,2})'
        ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectSingleNode('.//div[contains(@class, "release-note")]') | Get-TextContent | Format-Text
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
