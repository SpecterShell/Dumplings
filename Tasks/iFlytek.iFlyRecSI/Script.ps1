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
  $Task.Logging('The installer does not match the version', 'Warning')

  # Version
  $Task.CurrentState.Version = [regex]::Match($InstallerUrl, 'setup_([\d\.]+)').Groups[1].Value
}

switch ($Task.Check()) {
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
        $Task.Logging("No ReleaseNotes for version $($Task.CurrentState.Version)", 'Warning')
      }
    } catch {
      $Task.Logging($_, 'Warning')
    }

    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 }) {
    $Task.Submit()
  }
}
