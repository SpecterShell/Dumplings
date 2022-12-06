$Object = Invoke-RestMethod -Uri 'http://fm.dl.126.net/mailmaster/update2/update_config.json'

# Version
$Task.CurrentState.Version = $Object.full[0].ver

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.full[0].url
}

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.full[0].introduction | Split-LineEndings | Select-Object -Skip 1 | Select-Object -SkipLast 2 | Format-Text
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
