$Params = @{
  Method      = 'Post'
  Body        = @{
    page     = 1
    pageSize = 999
    platform = 1
    type     = 6
  } | ConvertTo-Json -Compress
  ContentType = 'application/json'
}
$Header = @{
  __CXY_APP_CH_   = 'creality'
  __CXY_APP_ID_   = 'creality_model'
  __CXY_APP_VER_  = '6.0.0'
  __CXY_BRAND_    = 'creality'
  __CXY_DUID_     = (New-Guid).Guid
  __CXY_OS_LANG_  = '0'
  __CXY_OS_VER_   = 'win'
  __CXY_PLATFORM_ = '11'
  __CXY_TIMEZONE_ = '0'
}

# Global en-US
$Object1 = Invoke-RestMethod -Uri 'https://api.crealitycloud.com/api/cxy/search/softwareSearch' -Headers $Header @Params
# China en-US
$Object2 = Invoke-RestMethod -Uri 'https://api.crealitycloud.cn/api/cxy/search/softwareSearch' -Headers $Header @Params

if ($Object1.result.list[0].versionNumber -ne $Object2.result.list[0].versionNumber) {
  $this.Log("Inconsistent versions: Global: $($Object1.result.list[0].versionNumber), China: $($Object2.result.list[0].versionNumber)", 'Error')
  return
}

# Version
$this.CurrentState.Version = [regex]::Match($Object1.result.list[0].versionNumber, '(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType        = 'zip'
  NestedInstallerFiles = @([ordered]@{ RelativeFilePath = "$($Object1.result.list[0].name).exe" })
  InstallerUrl         = $Object1.result.list[0].fileUrl
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale      = 'zh-CN'
  InstallerType        = 'zip'
  NestedInstallerFiles = @([ordered]@{ RelativeFilePath = "$($Object2.result.list[0].name).exe" })
  InstallerUrl         = $Object2.result.list[0].fileUrl
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.result.list[0].createTime | ConvertFrom-UnixTimeSeconds

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object1.result.list[0].description | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      # Global zh-CN
      $Object3 = Invoke-RestMethod -Uri 'https://api.crealitycloud.com/api/cxy/search/softwareSearch' -Headers @{
        __CXY_APP_CH_   = 'creality'
        __CXY_APP_ID_   = 'creality_model'
        __CXY_APP_VER_  = $this.Status.Contains('New') ? '6.2.0.2828' : $this.LastState.Version
        __CXY_BRAND_    = 'creality'
        __CXY_DUID_     = '00:00:00:00:00:00'
        __CXY_OS_LANG_  = '1'
        __CXY_OS_VER_   = 'win'
        __CXY_PLATFORM_ = '11'
        __CXY_TIMEZONE_ = '0'
      } @Params

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object3.result.list[0].description | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
