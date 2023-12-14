$Object1 = Invoke-WebRequest -Uri 'https://www.todesk.com/download.html' | ConvertFrom-Html

# Version
$Task.CurrentState.Version = [regex]::Match(
  $Object1.SelectSingleNode('/html/body/div/div/div/div[1]/div[2]/div[1]/div[1]/section/a').InnerText,
  '([\d\.]+)'
).Groups[1].Value

try {
  $InstallerUrl = "https://dl.todesk.com/irrigation/ToDesk_$($Task.CurrentState.Version).exe"
  Invoke-WebRequest -Uri $InstallerUrl -Method Head | Out-Null
  # Installer
  $Task.CurrentState.Installer += [ordered]@{
    InstallerUrl = $InstallerUrl
  }
} catch {
  $Task.Logging("${InstallerUrl} doesn't exist, fallback to $($Object1.soft.https.'#cdata-section')", 'Warning')
  # Installer
  $Task.CurrentState.Installer += [ordered]@{
    InstallerUrl = $Object1.SelectSingleNode('/html/body/div/div/div/div[1]/div[2]/div[1]/div[1]/section/div[1]/a').Attributes['href'].Value
  }
}

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Object2 = Invoke-WebRequest -Uri 'https://update.todesk.com/windows/uplog.html' | ConvertFrom-Html

    try {
      $ReleaseNotesNode = $Object2.SelectSingleNode("//div[@class='row' and contains(./div[1]/div[1]/div[1], '$($Task.CurrentState.Version)')]")
      if ($ReleaseNotesNode) {
        # ReleaseTime
        $Task.CurrentState.ReleaseTime = [regex]::Match(
          $ReleaseNotesNode.SelectSingleNode('./div[1]/div[2]').InnerText,
          '(\d{4}\.\d{1,2}\.\d{1,2})'
        ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (zh-CN)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectSingleNode('./div[2]') | Get-TextContent | Format-Text
        }
      } else {
        $Task.Logging("No ReleaseTime and ReleaseNotes for version $($Task.CurrentState.Version)", 'Warning')
      }
    } catch {
      $Task.Logging($_, 'Warning')
    }

    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 }) {
    $Task.Submit()
  }
}
