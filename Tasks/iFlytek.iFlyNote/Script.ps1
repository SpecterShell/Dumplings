$Object1 = Invoke-RestMethod -Uri "https://api.iflynote.com/user/version/info?from=IFLYNOTE_PC_WINDOWS&clientVersion=$($Task.LastState.Version ?? '3.1.1254')"

# Version
$Task.CurrentState.Version = $Object1.data.versionName

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = Get-RedirectedUrl -Uri 'https://download.iflynote.com/voicenote_pc_win'
}

# Sometimes the installer does not match the version
if ($InstallerUrl.Contains($Task.CurrentState.Version)) {
  # ReleaseNotes (zh-CN)
  $Task.CurrentState.Locale += [ordered]@{
    Locale = 'zh-CN'
    Key    = 'ReleaseNotes'
    Value  = $Object1.data.updateDetail | Format-Text
  }
} else {
  Write-Host -Object "Task $($Task.Name): The installer does not match the version" -ForegroundColor Yellow

  # Version
  $Task.CurrentState.Version = [regex]::Match($InstallerUrl, '([\d\.]+)\.exe').Groups[1].Value
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    $Prefix = 'https://bj.openstorage.cn/v1/yuji/public/release/'

    $Object2 = Invoke-WebRequest -Uri "${Prefix}latest.yml?noCache=$((New-Guid).Guid.Split('-')[0])" | Read-ResponseContent | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix -Locale 'zh-CN'

    if ($Object2.Version -eq $Task.CurrentState.Version) {
      # ReleaseTime
      $Task.CurrentState.ReleaseTime = $Object2.ReleaseTime
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
