$Object1 = Invoke-RestMethod -Uri "https://api.iflynote.com/user/version/info?from=IFLYNOTE_PC_WINDOWS&clientVersion=$($Task.LastState.Version ?? '3.1.1254')"

if ($Object1.code -eq 50002) {
  $Task.Logging("The last version $($Task.LastState.Version) is the latest, skip checking", 'Warning')
  return
}

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
  $Task.Logging('The installer does not match the version', 'Warning')

  # Version
  $Task.CurrentState.Version = [regex]::Match($InstallerUrl, '([\d\.]+)\.exe').Groups[1].Value
}

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Prefix = 'https://bj.openstorage.cn/v1/yuji/public/release/'

    $Object2 = Invoke-WebRequest -Uri "${Prefix}latest.yml?noCache=$((New-Guid).Guid.Split('-')[0])" | Read-ResponseContent | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix -Locale 'zh-CN'

    if ($Object2.Version -eq $Task.CurrentState.Version) {
      # ReleaseTime
      $Task.CurrentState.ReleaseTime = $Object2.ReleaseTime
    } else {
      $Task.Logging("No ReleaseNotes and ReleaseTime for version $($Task.CurrentState.Version)", 'Warning')
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
