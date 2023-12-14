$Object = Invoke-RestMethod -Uri 'https://www.123pan.com/api/version_upgrade' -Headers @{
  'platform'    = 'pc'
  'app-version' = $Task.LastState.Version.Split('.')[2] ?? 109
}

if (-not $Object.data.hasNewVersion) {
  $Task.Logging("The last version $($Task.LastState.Version) is the latest, skip checking", 'Info')
  return
}

$Prefix = $Object.data.url + '/'

$Task.CurrentState = Invoke-RestMethod -Uri "${Prefix}latest.yml?noCache=$((New-Guid).Guid.Split('-')[0])" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix -Locale 'zh-CN'

if ($Object.data.lastVersion -ne $Task.CurrentState.Version) {
  $Task.Logging('Distinct versions between two response objects', 'Warning')
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

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    # RealVersion
    $Task.CurrentState.RealVersion = Get-TempFile -Uri $Task.CurrentState.Installer[0].InstallerUrl | Read-ProductVersionFromExe

    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 }) {
    $Task.Submit()
  }
}
