$Object1 = Invoke-RestMethod -Uri 'https://cadreader.glodon.com/query/update/cadpc?clientVersion=3.4.3.12&cadpcClientBits=32'

# Version
$Task.CurrentState.Version = $Object1.data.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.url
}

# ReleaseNotesUrl
$ReleaseNotesUrl = $Object1.data.pageUrl
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
        Value  = $Object2.SelectNodes('/html/body/div/p[2]/following-sibling::p[count(.|/html/body/div/br/preceding-sibling::p)=count(/html/body/div/br/preceding-sibling::p)]').InnerText | Format-Text
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
