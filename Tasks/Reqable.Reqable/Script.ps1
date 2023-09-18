$Object1 = Invoke-RestMethod -Uri 'https://api.reqable.com/version/check?platform=windows&arch=x86_64'

# Version
$Task.CurrentState.Version = $Object1.name

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl1st -Uri 'https://api.reqable.com/download?platform=windows&arch=x86_64' -Headers @{ 'Accept-Language' = 'en' }
}
$Task.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  InstallerUrl    = $Object1.url
}

# ReleaseNotes (en-US)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotes'
  Value  = $Object1.changelogs.'en-US' | Format-Text
}
# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object1.changelogs.'zh-CN' | Format-Text
}


switch (Compare-State) {
  ({ $_ -ge 1 }) {
    try {
      $Object2 = Invoke-RestMethod -Uri "https://api.github.com/repos/reqable/reqable-app/releases/tags/$($Task.CurrentState.Version)"

      # ReleaseTime
      $Task.CurrentState.ReleaseTime = ($Object2.assets | Where-Object -Property name -CMatch '\.exe$').updated_at

      # ReleaseNotesUrl
      $Task.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = "https://github.com/reqable/reqable-app/releases/tag/$($Task.CurrentState.Version)"
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
