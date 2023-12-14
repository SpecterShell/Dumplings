$Object1 = Invoke-WebRequest -Uri 'https://browser.360.cn/eex/' | ConvertFrom-Html

# Version
$Task.CurrentState.Version = [regex]::Match(
  $Object1.SelectSingleNode('/html/body/div[3]/div[1]/p[2]').InnerText,
  '([\d\.]+)'
).Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.SelectSingleNode('//*[@id="download"]').Attributes['href'].Value
}

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Object2 = Invoke-WebRequest -Uri 'https://bbs.360.cn/thread-16105183-1-1.html' | ConvertFrom-Html

    try {
      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//*[@id='postmessage_119165366']/text()[contains(., '$($Task.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $Task.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.InnerText, '(\d{4}\.\d{1,2}\.\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (zh-CN)
        $ReleaseNotesNodes = @()
        for ($Node = $ReleaseNotesTitleNode.NextSibling; -not $Node.InnerText.Contains('版本号'); $Node = $Node.NextSibling) {
          $ReleaseNotesNodes += $Node
        }
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
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
