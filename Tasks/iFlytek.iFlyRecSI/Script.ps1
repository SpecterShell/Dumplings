$Object1 = (Invoke-RestMethod -Uri 'https://tongchuan.iflyrec.com/exhibition/v1/ClientPackage/selectLatestList').data.Where({ $_.osType -eq 1 })[0]

# Version
$Task.CurrentState.Version = $Object1.packageVersion

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = Get-RedirectedUrl -Uri 'https://tongchuan.iflyrec.com/download/tjhz/windows/TJTC001'
}

# Sometimes the installer does not match the version
if ($InstallerUrl.Contains($Task.CurrentState.Version)) {
  # ReleaseTime
  $Task.CurrentState.ReleaseTime = $Object1.releaseDate | ConvertFrom-UnixTimeMilliseconds
} else {
  Write-Host -Object "Task $($Task.Name): The installer does not match the version" -ForegroundColor Yellow

  # Version
  $Task.CurrentState.Version = [regex]::Match($InstallerUrl, 'setup_([\d\.]+)').Groups[1].Value
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    $Object2 = Invoke-RestMethod -Uri 'https://tongchuan.iflyrec.com/UpdateService/v1/updates/hardware/deltaPatch/check' -Method Post -Body (
      @{
        clientVersion = $Task.LastState.Version ?? '3.0.1374'
        deviceType    = 'WinOS'
        platform      = 7
      } | ConvertTo-Json -Compress
    ) -ContentType 'application/json'

    try {
      if ($Object2.biz.latestVersionUrl.Contains($Task.CurrentState.Version)) {
        # ReleaseNotes (zh-CN)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object2.biz.latestVersionInfo | Format-Text
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
