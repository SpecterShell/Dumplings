$Object1 = Invoke-WebRequest -Uri 'https://modao.cc/feature/downloads.html' | ConvertFrom-Html

# Version
$Task.CurrentState.Version = [regex]::Match(
  $Object1.SelectSingleNode('/html/body/main/section[2]/div/div[3]').InnerText,
  'v([\d\.]+)'
).Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.SelectSingleNode('//*[@id="download-win32"]').Attributes['href'].Value
}
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.SelectSingleNode('//*[@id="download-win64"]').Attributes['href'].Value
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    $Object2 = Invoke-RestMethod -Uri "https://modao.cc/api/v2/client/desktop/check_update.json?region=CN&version=$($Task.LastState.Version ?? '1.2.5')&platform=win32&arch=x64"

    try {
      if ($Object2.version -eq $Task.CurrentState.Version) {
        # ReleaseTime
        $Task.CurrentState.ReleaseTime = $Object2.pub_date.ToUniversalTime()

        # ReleaseNotes (en-US)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object2.release_notes_en | Format-Text
        }
        # ReleaseNotes (zh-CN)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object2.release_notes_zh | Format-Text
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
