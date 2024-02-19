$Object1 = Invoke-RestMethod -Uri 'https://api.welink.huaweicloud.com/mcloud/mag/ProxyForText/pc/appstore_appservice/api/cloudlink/patch/free/check/version/pc/1' -Method Post -Body (
  @{
    appId    = 'com.huawei.cloud.welink'
    weDevice = '5'
    weOs     = '10'
    weVCode  = $this.LastState.VersionCode ?? 483
  } | ConvertTo-Json -Compress
) -ContentType 'application/json'

if ($Object1.data.status -eq 1) {
  $this.Log("The last version $($this.LastState.Version) is the latest, skip checking", 'Info')
  return
}

# Version
$this.CurrentState.Version = $Object1.data.versionName

# VersionCode
$this.CurrentState.VersionCode = $Object1.data.versionCode

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.updateUrl
}

# ReleaseNotes (en-US)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotes'
  Value  = $Object1.data.tipEN | Format-Text
}
# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object1.data.tipZH | Format-Text
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Write()
  }
  'Changed|Updated' {
    $this.Print()
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
