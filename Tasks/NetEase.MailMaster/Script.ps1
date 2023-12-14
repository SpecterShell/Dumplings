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
  Value  = $Object.full[0].introduction | Split-LineEndings | Select-Object -Skip 1 | Format-Text
}

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 }) {
    $Task.Submit()
  }
}
