$Params = @{
  Method               = 'Post'
  Body                 = @{
    client = @{
      app = @{
        id      = '100823621'
        version = $Task.LastState.Version ?? '11.2.0.303'
      }
    }
  } | ConvertTo-Json -Compress
  ContentType          = 'application/json'
  Headers              = @{
    Authorization       = 'Ojpjb20uaHVhd2VpLmNsb3VkLnBjOjo='
    'x-hw-auth-version' = 1
  }
  SkipHeaderValidation = $true
}

# Europe
$Object1 = (Invoke-RestMethod -Uri 'https://conf-dre.cloud.dbankcloud.cn/configserver/v1/hicloud/configs/HiCloudPCUpgradeConfig' @Params).config.content | ConvertFrom-Json

# China
$Object2 = (Invoke-RestMethod -Uri 'https://conf-drcn.cloud.dbankcloud.cn/configserver/v1/hicloud/configs/HiCloudPCUpgradeConfig' @Params).config.content | ConvertFrom-Json

# Russia
$Object3 = (Invoke-RestMethod -Uri 'https://conf-drru.cloud.dbankcloud.ru/configserver/v1/hicloud/configs/HiCloudPCUpgradeConfig' @Params).config.content | ConvertFrom-Json

# Version
$Task.CurrentState.Version = $Object1.configurations.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.configurations.fileInfo.Where({ $_.type -eq 1 }).url
}
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.configurations.fileInfo.Where({ $_.type -eq 2 }).url
}
$Task.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-Hans-CN'
  Architecture    = 'x86'
  InstallerUrl    = $Object2.configurations.fileInfo.Where({ $_.type -eq 1 }).url
}
$Task.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-Hans-CN'
  Architecture    = 'x64'
  InstallerUrl    = $Object2.configurations.fileInfo.Where({ $_.type -eq 2 }).url
}
$Task.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'ru'
  Architecture    = 'x86'
  InstallerUrl    = $Object3.configurations.fileInfo.Where({ $_.type -eq 1 }).url
}
$Task.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'ru'
  Architecture    = 'x64'
  InstallerUrl    = $Object3.configurations.fileInfo.Where({ $_.type -eq 2 }).url
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object1.configurations.publishTime | ConvertFrom-UnixTimeMilliseconds


switch (Compare-State) {
  ({ $_ -ge 1 }) {
    $Object4 = Invoke-WebRequest -Uri $Object1.configurations.language.url | Read-ResponseContent | ConvertFrom-Xml

    try {
      # ReleaseNotes (en-US)
      $Task.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object4.resource.'en-US'.text.value | Format-Text
      }

      # ReleaseNotes (zh-CN)
      $Task.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object4.resource.'zh-CN'.text.value | Format-Text
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
