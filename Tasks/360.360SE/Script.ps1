$Object1 = Invoke-WebRequest -Uri 'https://browser.360.cn/' | ConvertFrom-Html

# Version
$Task.CurrentState.Version = [regex]::Match($Object1.SelectSingleNode('//*[@class="browser_ver"]').InnerText, '([\d\.]+)').Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://down.360safe.com/se/360se$($Task.CurrentState.Version).exe"
}

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Object2 = Invoke-WebRequest -Uri 'https://bbs.360.cn/thread-16096544-1-1.html' | ConvertFrom-Html

    try {
      $ReleaseNotesTitle = $Object2.SelectSingleNode('//*[@id="postmessage_119112293"]/strong[2]').InnerText
      if ($ReleaseNotesTitle.Contains($Task.CurrentState.Version)) {
        # ReleaseTime
        $Task.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitle, '(\d{4}\.\d{1,2}\.\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (zh-CN)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object2.SelectNodes('//*[@id="postmessage_119112293"]/strong[2]/following-sibling::node()[count(.|//*[@id="postmessage_119112293"]/strong[3]/preceding-sibling::node())=count(//*[@id="postmessage_119112293"]/strong[3]/preceding-sibling::node())]') | Get-TextContent | Format-Text
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
