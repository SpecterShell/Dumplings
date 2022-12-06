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

switch (Compare-State) {
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
      Write-Host -Object "Task $($Task.Name): ${_}" -ForegroundColor Yellow
    }

    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
