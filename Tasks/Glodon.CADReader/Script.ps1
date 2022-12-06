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

switch (Compare-State) {
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
