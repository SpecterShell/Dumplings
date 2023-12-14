$Path = Get-TempFile -Uri 'https://ini.update.360safe.com/v3/360csaupd_manual.cab'
expand.exe -R $Path
$Object = Join-Path $Path '..' '360csaupd_manual.ini' -Resolve | Get-Item | Get-Content -Raw -Encoding 'gb18030' | ConvertFrom-Ini

# Version
$Task.CurrentState.Version = $Object.'360App1'.ver

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://down.360safe.com/360CleanMasterPC/' + $Object.'360App1'.files
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object.'360App1'.date | Get-Date -Format 'yyyy-MM-dd'

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.'360App1'.tip | Format-Text
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
