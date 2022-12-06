$Object1 = Invoke-RestMethod -Uri 'https://api.kuaishouzt.com/rest/zt/appsupport/checkupgrade?appver=0.0.0.0&kpn=ACFUN_APP.LIVE.PC&kpf=WINDOWS_PC'

# Version
$Task.CurrentState.Version = $Object1.releaseInfo.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.releaseInfo.downloadUrl
}

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object1.releaseInfo.message | Format-Text
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    $Headers = @{
      Referer = 'https://livetool.kuaishou.com'
    }
    $Key = (Invoke-RestMethod -Uri 'https://ytech-ai.kuaishou.cn/ytech/api/register' -Headers $Headers -SkipHeaderValidation).Split(':')[0]
    $Object2 = Invoke-RestMethod -Uri "https://ytech-ai.kuaishou.cn/ytech/api/virtual/reconstruct/record?api_key=${Key}&timestamp=$([System.DateTimeOffset]::Now.ToUnixTimeMilliseconds())" -Headers $Headers -SkipHeaderValidation

    try {
      $ReleaseNotesUrl = $Object2.data.data.Where({ $_.iconText.Contains([regex]::Match($Task.CurrentState.Version, '(\d+\.\d+)').Groups[1].Value) })[0].link
      if ($ReleaseNotesUrl) {
        # ReleaseNotesUrl
        $Task.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $ReleaseNotesUrl
        }
      } else {
        $Task.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $null
        }
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
