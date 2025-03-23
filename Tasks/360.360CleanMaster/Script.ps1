$Path = Get-TempFile -Uri 'https://ini.update.360safe.com/v3/360csaupd_manual.cab'
expand.exe -R $Path | Out-Host
$Object1 = Join-Path $Path '..' '360csaupd_manual.ini' -Resolve | Get-Item | Get-Content -Raw -Encoding 'gb18030' | ConvertFrom-Ini
Remove-Item -Path $Path -Recurse -Force -ErrorAction 'SilentlyContinue' -WarningAction 'SilentlyContinue'

# Version
$this.CurrentState.Version = $Object1.'360App1'.ver

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://down.360safe.com/360CleanMasterPC/' + $Object1.'360App1'.files
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.'360App1'.date | Get-Date -Format 'yyyy-MM-dd'

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.'360App1'.tip | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
