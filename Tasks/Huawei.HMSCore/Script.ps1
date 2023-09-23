# Europe en-US
$Object1 = Invoke-RestMethod -Uri 'https://store-dre.hispace.dbankcloud.cn/hwmarket/api/clientApi' -Method Post -Body @{
  method      = 'openservice.app.pcupdate'
  pkgName     = 'HMS Core'
  versionName = $Task.LastState.Version ?? '5.1.0.300'
  locale      = 'en_US'
  country     = 'EU'
}

# Europe zh-CN
$Object2 = Invoke-RestMethod -Uri 'https://store-dre.hispace.dbankcloud.cn/hwmarket/api/clientApi' -Method Post -Body @{
  method      = 'openservice.app.pcupdate'
  pkgName     = 'HMS Core'
  versionName = $Task.LastState.Version ?? '5.1.0.300'
  locale      = 'zh_CN'
  country     = 'EU'
}

# China en-US
$Object3 = Invoke-RestMethod -Uri 'https://store-drcn.hispace.dbankcloud.cn/hwmarket/api/clientApi' -Method Post -Body @{
  method      = 'openservice.app.pcupdate'
  pkgName     = 'HMS Core'
  versionName = $Task.LastState.Version ?? '5.1.0.300'
  locale      = 'en_US'
  country     = 'CN'
}

# Russia en-US
$Object4 = Invoke-RestMethod -Uri 'https://store-drru.hispace.dbankcloud.ru/hwmarket/api/clientApi' -Method Post -Body @{
  method      = 'openservice.app.pcupdate'
  pkgName     = 'HMS Core'
  versionName = $Task.LastState.Version ?? '5.1.0.300'
  locale      = 'en_US'
  country     = 'RU'
}

# Version
$Task.CurrentState.Version = $Object1.updateAppInfo.versionName

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = ([uri]$Object1.updateAppInfo.downurl).GetLeftPart([System.UriPartial]::Path)
}
$Task.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-Hans-CN'
  InstallerUrl    = ([uri]$Object3.updateAppInfo.downurl).GetLeftPart([System.UriPartial]::Path)
}
$Task.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'ru'
  InstallerUrl    = ([uri]$Object4.updateAppInfo.downurl).GetLeftPart([System.UriPartial]::Path)
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object1.updateAppInfo.releaseDate | ConvertFrom-UnixTimeMilliseconds

# ReleaseNotes (en-US)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotes'
  Value  = $Object1.updateAppInfo.newFeatures | Format-Text
}

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object2.updateAppInfo.newFeatures | Format-Text
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
