$Object1 = Invoke-RestMethod -Uri 'https://ieltsbro.com/hcp/base/base/officeGetConfigInfo'

# Version
$Task.CurrentState.Version = [regex]::Match($Object1.content.pcWindowsUrl, '([\d\.]+)\.exe').Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.content.pcWindowsUrl
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    $Object2 = Invoke-RestMethod -Uri "https://hcp-server.ieltsbro.com/hcp/base/base/getPcUpdateVersion?osType=pc&appVersion=$($Task.LastState.Version ?? '2.1.2')"

    if ($Object2.content.version -eq $Task.CurrentState.Version) {
      try {
        # ReleaseNotes (zh-CN)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object2.content.description | ConvertFrom-Html | Get-TextContent | Format-Text
        }
      } catch {
        Write-Host -Object "Task $($Task.Name): ${_}" -ForegroundColor Yellow
      }

      $Object3 = Invoke-WebRequest -Uri "$($Object2.content.url)/latest.yml" | Read-ResponseContent | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix "$($Object2.content.url)/" -Locale 'zh-CN'

      try {
        # ReleaseTime
        $Task.CurrentState.ReleaseTime = $Object3.ReleaseTime
      } catch {
        Write-Host -Object "Task $($Task.Name): ${_}" -ForegroundColor Yellow
      }
    } else {
      Write-Host -Object "Task $($Task.Name): No ReleaseNotes and ReleaseTime for version $($Task.CurrentState.Version)" -ForegroundColor Yellow
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
