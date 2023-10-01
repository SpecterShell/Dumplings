$Object = Invoke-RestMethod -Uri 'https://api.welink.huaweicloud.com/mcloud/mag/ProxyForText/pc/appstore_appservice/api/cloudlink/patch/free/check/version/pc/1' -Method Post -Body (
  @{
    appId    = 'com.huawei.cloud.welink'
    weDevice = '5'
    weOs     = '10'
    weVCode  = $Task.LastState.VersionCode ?? 483
  } | ConvertTo-Json -Compress
) -ContentType 'application/json'

if ($Object.data.status -eq 1) {
  Write-Host -Object "Task $($Task.Name): The last version $($Task.LastState.Version) is the latest, skip checking" -ForegroundColor Yellow
  return
}

# Version
$Task.CurrentState.Version = $Object.data.versionName

# VersionCode
$Task.CurrentState.VersionCode = $Object.data.versionCode

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.data.updateUrl
}

# ReleaseNotes (en-US)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotes'
  Value  = $Object.data.tipEN | Format-Text
}

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.data.tipZH | Format-Text
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
