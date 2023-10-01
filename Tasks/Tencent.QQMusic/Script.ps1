$Object1 = Invoke-WebRequest -Uri 'https://u.y.qq.com/cgi-bin/musicu.fcg' -Method Post -Body (
  @{
    comm                                              = @{
      ct       = '19'
      cv       = '0'
      tmeAppID = 'qqmusic'
    }
    'platform.uniteUpdate.UniteUpdateSvr.QueryUpdate' = @{
      method = 'QueryUpdate'
      module = 'platform.uniteUpdate.UniteUpdateSvr'
      param  = @{}
    }
  } | ConvertTo-Json -Compress
) | Read-ResponseContent | ConvertFrom-Json

# Version
$Task.CurrentState.Version = $Object1.'platform.uniteUpdate.UniteUpdateSvr.QueryUpdate'.data.pkgVersion.ToString().Insert(2, '.')

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.'platform.uniteUpdate.UniteUpdateSvr.QueryUpdate'.data.pkgUrl.Replace('dldir1.qq.com', 'dldir1v6.qq.com') | ConvertTo-Https
}

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = '"' + $Object1.'platform.uniteUpdate.UniteUpdateSvr.QueryUpdate'.data.pkgDesc + '"' | ConvertFrom-Json | Format-Text | ConvertTo-UnorderedList
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    $Object2 = Invoke-WebRequest -Uri 'https://y.qq.com/download/download.html' | ConvertFrom-Html

    try {
      if ($Object2.SelectSingleNode('/html/body/div[2]/div[2]/ul/li[1]/h3/span').InnerText.Contains($Task.CurrentState.Version)) {
        # ReleaseTime
        $Task.CurrentState.ReleaseTime = [regex]::Match(
          $Object2.SelectSingleNode('/html/body/div[2]/div[2]/ul/li[1]/ul/li[last()]').InnerText,
          '(\d{4}-\d{1,2}-\d{1,2})'
        ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
      } else {
        Write-Host -Object "Task $($Task.Name): No ReleaseTime for version $($Task.CurrentState.Version)" -ForegroundColor Yellow
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
