$Params = @{
  Method      = 'Post'
  Body        = @{
    page     = 1
    pageSize = 999
    platform = 1
    type     = 11
  } | ConvertTo-Json -Compress
  ContentType = 'application/json'
}
$Header = @{
  __CXY_APP_CH_   = 'creality'
  __CXY_APP_ID_   = 'creality_model'
  __CXY_APP_VER_  = $this.Status.Contains('New') ? '2.5.14' : $this.LastState.Version
  __CXY_BRAND_    = 'creality'
  __CXY_DUID_     = '00:00:00:00:00:00'
  __CXY_OS_LANG_  = '0'
  __CXY_OS_VER_   = 'win'
  __CXY_PLATFORM_ = '11'
  __CXY_TIMEZONE_ = '0'
}

# Global en-US
$Object1 = Invoke-RestMethod -Uri 'https://api.crealitycloud.com/api/cxy/search/softwareSearch' -Headers $Header @Params
$Version = [regex]::Match($Object1.result.list[0].fileUrl, '(\d+(?:\.\d+){3,})').Groups[1].Value
# China en-US
$Object2 = Invoke-RestMethod -Uri 'https://api.crealitycloud.cn/api/cxy/search/softwareSearch' -Headers $Header @Params
$VersionCN = [regex]::Match($Object2.result.list[0].fileUrl, '(\d+(?:\.\d+){3,})').Groups[1].Value

if ($Version -ne $VersionCN) {
  $this.Log("Inconsistent versions: Global: ${Version}, China: ${VersionCN}", 'Error')
  return
}

# Version
$this.CurrentState.Version = $Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.result.list[0].fileUrl
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  InstallerUrl    = $Object2.result.list[0].fileUrl
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

    foreach ($Installer in $this.CurrentState.Installer) {
      $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl | Rename-Item -NewName { "${_}.exe" } -PassThru | Select-Object -ExpandProperty 'FullName'
      $InstallerFileExtracted = New-TempFolder
      Start-Process -FilePath $InstallerFile -ArgumentList @('/extract', $InstallerFileExtracted) -Wait
      $InstallerFile2 = Join-Path $InstallerFileExtracted 'CR Studio.msi'
      # ProductCode
      $Installer['ProductCode'] = $InstallerFile2 | Read-ProductCodeFromMsi
      # AppsAndFeaturesEntries
      $Installer['AppsAndFeaturesEntries'] = @(
        [ordered]@{
          UpgradeCode   = $InstallerFile2 | Read-UpgradeCodeFromMsi
          InstallerType = 'msi'
        }
      )
      Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
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
