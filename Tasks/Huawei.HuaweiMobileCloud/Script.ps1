$Params = @{
  Method               = 'Post'
  Body                 = @{
    client = @{
      app    = @{
        id      = '100823621'
        version = $this.LastState.Version ?? '11.2.0.303'
      }
      device = @{
        osVersion = '10.0.22000.0'
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
# $Object1 = (Invoke-RestMethod -Uri 'https://conf-dre.cloud.dbankcloud.cn/configserver/v1/hicloud/configs/HiCloudPCUpgradeConfig' @Params).config.content | ConvertFrom-Json

# China
$Object2 = (Invoke-RestMethod -Uri 'https://conf-drcn.cloud.dbankcloud.cn/configserver/v1/hicloud/configs/HiCloudPCUpgradeConfig' @Params).config.content | ConvertFrom-Json

# Russia
# $Object3 = (Invoke-RestMethod -Uri 'https://conf-drru.cloud.dbankcloud.ru/configserver/v1/hicloud/configs/HiCloudPCUpgradeConfig' @Params).config.content | ConvertFrom-Json

# Version
$this.CurrentState.Version = $Object2.configurations.version

# Installer
# $this.CurrentState.Installer += [ordered]@{
#   Architecture = 'x64'
#   InstallerUrl = $Object1.configurations.fileInfo.Where({ $_.type -eq 2 }, 'First')[0].url
# }
$this.CurrentState.Installer += [ordered]@{
  # InstallerLocale = 'zh-Hans-CN'
  Architecture = 'x64'
  InstallerUrl = $Object2.configurations.fileInfo.Where({ $_.type -eq 2 }, 'First')[0].url
}
# $this.CurrentState.Installer += [ordered]@{
#   InstallerLocale = 'ru'
#   Architecture    = 'x64'
#   InstallerUrl    = $Object3.configurations.fileInfo.Where({ $_.type -eq 2 }, 'First')[0].url
# }

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.configurations.publishTime | ConvertFrom-UnixTimeMilliseconds
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object4 = Invoke-WebRequest -Uri $Object2.configurations.language.url | Read-ResponseContent | ConvertFrom-Xml

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object4.resource.'en-US'.text.value | Format-Text
      }
      # ReleaseNotes (zh-Hans)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-Hans'
        Key    = 'ReleaseNotes'
        Value  = $Object4.resource.'zh-CN'.text.value | Format-Text
      }
      # ReleaseNotes (zh-Hans-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-Hans-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object4.resource.'zh-CN'.text.value | Format-Text
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
