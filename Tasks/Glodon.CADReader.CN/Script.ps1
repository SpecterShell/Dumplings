$Object1 = Invoke-RestMethod -Uri 'https://cad.glodon.com/update/version/info/cadpc'

# Version
$Task.CurrentState.Version = $Object1.body.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.body.url
}

# ReleaseNotesUrl
$ReleaseNotesUrl = $Object1.body.pageUrl
$Task.CurrentState.Locale += [ordered]@{
  Key   = 'ReleaseNotesUrl'
  Value = $ReleaseNotesUrl
}

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

    try {
      # ReleaseNotes (zh-CN)
      $Task.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object2.SelectNodes('/html/body/div/p[@style="margin-top: 30px;"]/following-sibling::p[count(.|/html/body/div/p[@style="margin-top:30px;"]/preceding-sibling::p)=count(/html/body/div/p[@style="margin-top:30px;"]/preceding-sibling::p)]').InnerText | Format-Text
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
