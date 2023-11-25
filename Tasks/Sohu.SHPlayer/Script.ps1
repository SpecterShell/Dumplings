$Object1 = Invoke-RestMethod -Uri 'https://p2p.hd.sohu.com.cn/update?clienttype=3&version=7.0.0.0'

# Version
$Task.CurrentState.Version = $Object1.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.cdn
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    $Object2 = Invoke-WebRequest -Uri 'https://tv.sohu.com/down/index.shtml?downLoad=windows' | Read-ResponseContent -Encoding 'GBK' | ConvertFrom-Html

    try {
      if ($Object2.SelectSingleNode('//div[contains(@class, "down_winbox")]/div[2]/div/p/span').InnerText.Contains($Task.CurrentState.Version)) {
        # ReleaseTime
        $Task.CurrentState.ReleaseTime = [regex]::Match(
          $Object2.SelectSingleNode('//div[contains(@class, "down_winbox")]/div[2]/div/p/span').InnerText,
          '(\d{4}-\d{1,2}-\d{1,2})'
        ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (zh-CN)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object2.SelectNodes('//div[contains(@class, "down_winbox")]/div[2]/div/div') | Get-TextContent | Format-Text
        }
      } else {
        Write-Host -Object "Task $($Task.Name): No ReleaseTime and ReleaseNotes for version $($Task.CurrentState.Version)" -ForegroundColor Yellow
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
