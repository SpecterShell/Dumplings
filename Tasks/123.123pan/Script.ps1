$Object = Invoke-RestMethod -Uri 'https://www.123pan.com/api/version_upgrade' -Headers @{
  'platform'    = 'pc'
  'app-version' = $Task.LastState.Version.Split('.')[2] ?? 109
}

if (-not $Object.data.hasNewVersion) {
  Write-Host -Object "Task $($Task.Name): The last version $($Task.LastState.Version) is the latest, skip checking" -ForegroundColor Yellow
  return
}

$Prefix = $Object.data.url + '/'

$Task.CurrentState = Invoke-RestMethod -Uri "${Prefix}latest.yml?noCache=$((New-Guid).Guid.Split('-')[0])" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix -Locale 'zh-CN'

if ($Object.data.lastVersion -ne $Task.CurrentState.Version) {
  Write-Host -Object "Task $($Task.Name): Distinct versions between two response objects"
  $Task.Config.Notes = '检测到不同的版本'
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object.data.lastVersionCreate | ConvertTo-UtcDateTime -Id 'China Standard Time'

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.data.desc | Format-Text
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    # RealVersion
    $Task.CurrentState.RealVersion = Get-TempFile -Uri $Task.CurrentState.Installer[0].InstallerUrl | Read-ProductVersionFromExe

    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
