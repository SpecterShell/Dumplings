$Object1 = Invoke-RestMethod -Uri 'https://pinyin.thunisoft.com/webapi/v1/setup/setupinfo?os=win'

# Version
$Task.CurrentState.Version = $Object1.result.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.result.addr.Replace(':443', '')
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object1.result.date | Get-Date -Format 'yyyy-MM-dd'

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    $Object2 = (Invoke-RestMethod -Uri 'https://pinyin.thunisoft.com/webapi/v1/version/getpublishupdatelog').result | Where-Object -Property version -EQ -Value $Task.CurrentState.Version

    try {
      if ($Object2) {
        # ReleaseNotes (zh-CN)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object2.newfeature | Split-LineEndings | Select-Object -Skip 1 | Format-Text
        }
      } else {
        Write-Host -Object "Task $($Task.Name): No ReleaseNotes for version $($Task.CurrentState.Version)" -ForegroundColor Yellow
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
