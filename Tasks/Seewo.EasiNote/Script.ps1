$Object1 = Invoke-RestMethod -Uri 'https://easinote.seewo.com/com/softinfo?softCode=EasiNote5'

# Version
$Task.CurrentState.Version = $Object1.data[0].softVersion

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data[0].downloadUrl
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object1.data[0].softPublishtime | ConvertFrom-UnixTimeMilliseconds

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    $Object2 = (Invoke-RestMethod -Uri 'https://easinote.seewo.com/com/apis?api=GET_LOG').data | Where-Object -Property version -EQ -Value $Task.CurrentState.Version

    try {
      if ($Object2) {
        # ReleaseNotes (zh-CN)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object2.description | ConvertFrom-Html | Get-TextContent | Format-Text
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
