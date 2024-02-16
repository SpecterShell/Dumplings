$Object1 = Invoke-WebRequest -Uri 'https://www.todesk.com/download.html' | ConvertFrom-Html

# Version
$this.CurrentState.Version = [regex]::Match(
  $Object1.SelectSingleNode('//div[contains(@class, "win")]/section/a[@class="vinfo"]').InnerText,
  '([\d\.]+)'
).Groups[1].Value

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

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
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

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
