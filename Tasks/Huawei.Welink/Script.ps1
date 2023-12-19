$Object = Invoke-RestMethod -Uri 'https://api.welink.huaweicloud.com/mcloud/mag/ProxyForText/pc/appstore_appservice/api/cloudlink/patch/free/check/version/pc/1' -Method Post -Body (
  @{
    appId    = 'com.huawei.cloud.welink'
    weDevice = '5'
    weOs     = '10'
    weVCode  = $this.LastState.VersionCode ?? 483
  } | ConvertTo-Json -Compress
) -ContentType 'application/json'

if ($Object.data.status -eq 1) {
  $this.Logging("The last version $($this.LastState.Version) is the latest, skip checking", 'Info')
  return
}

# Version
$this.CurrentState.Version = $Object.data.versionName

# VersionCode
$this.CurrentState.VersionCode = $Object.data.versionCode

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.data.updateUrl
}

# ReleaseNotes (en-US)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotes'
  Value  = $Object.data.tipEN | Format-Text
}

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.data.tipZH | Format-Text
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
