$Path = Get-TempFile -Uri 'https://ini.update.360safe.com/v3/360csaupd_manual.cab'
expand.exe -R $Path
$Object = Join-Path $Path '..' '360csaupd_manual.ini' -Resolve | Get-Item | Get-Content -Raw -Encoding 'gb18030' | ConvertFrom-Ini

# Version
$this.CurrentState.Version = $Object.'360App1'.ver

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://down.360safe.com/360CleanMasterPC/' + $Object.'360App1'.files
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object.'360App1'.date | Get-Date -Format 'yyyy-MM-dd'

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.'360App1'.tip | Format-Text
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
