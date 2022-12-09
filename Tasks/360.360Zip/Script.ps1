$Object1 = Invoke-WebRequest -Uri 'https://www.360totalsecurity.com/en/360zip/' | ConvertFrom-Html

# Version
$Task.CurrentState.Version = [regex]::Match(
  $Object1.SelectSingleNode('//*[@id="primary-actions"]/p/span').InnerText,
  '([\d\.]+)'
).Groups[1].Value

$Object2 = Invoke-WebRequest -Uri 'https://www.360totalsecurity.com/en/download-free-360-zip/' | ConvertFrom-Html

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https:' + $Object2.SelectSingleNode('//*[@id="download-intro"]/div[1]/a').Attributes['href'].Value
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    $Path = Get-TempFile -Uri 'http://iup.360safe.com/iv3/pc/360zip/360zipupd_manual.cab'
    expand.exe -R $Path
    $Object3 = Join-Path $Path '..' '360zipupd_manual.ini' -Resolve | Get-Item | Get-Content -Raw -Encoding 'gb18030' | ConvertFrom-Ini

    try {
      if ($Object3.'360App1'.ver -eq $Task.CurrentState.Version) {
        # ReleaseTime
        $Task.CurrentState.ReleaseTime = $Object3.'360App1'.date | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (zh-CN)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object3.'360App1'.'tip_zh-CN' | Format-Text
        }
      } else {
        Write-Host -Object "Task $($Task.Name): No ReleaseTime and ReleaseNotes (zh-CN) for version $($Task.CurrentState.Version)" -ForegroundColor Yellow
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
