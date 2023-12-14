$Object1 = Invoke-WebRequest -Uri 'https://input.kfsafe.cn/' | ConvertFrom-Html

# Version
$Task.CurrentState.Version = [regex]::Match(
  $Object1.SelectSingleNode('/html/body/div[1]/div/div/p[5]/text()[1]').InnerText,
  '([\d\.]+)'
).Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.SelectSingleNode('/html/body/div[1]/div/div/a').Attributes['href'].Value
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = [regex]::Match(
  $Object1.SelectSingleNode('/html/body/div[1]/div/div/p[5]/text()[2]').InnerText,
  '(\d{4}\.\d{1,2}\.\d{1,2})'
).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Object2 = Invoke-WebRequest -Uri 'https://input.kfsafe.cn/logs.html' | ConvertFrom-Html

    try {
      $ReleaseNotesNode = $Object2.SelectSingleNode("/html/body/div/div[2]/div/div[contains(./h3/span[1]/text(), '$($Task.CurrentState.Version)')]")
      if ($ReleaseNotesNode) {
        # ReleaseNotes (zh-CN)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectNodes('./h3/following-sibling::*').InnerText | Format-Text
        }
      } else {
        $Task.Logging("No ReleaseNotes for version $($Task.CurrentState.Version)", 'Warning')
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
