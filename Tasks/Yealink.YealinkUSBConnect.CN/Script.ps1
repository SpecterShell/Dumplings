$Params = @{
  Uri         = 'https://update.yealink.com.cn/yiot-manager/api/v1/external/software/checkVersion'
  Method      = 'Post'
  ContentType = 'application/json;charset=UTF-8'
  Body        = @{
    appId          = '72bbc75337eb4930ad93a5e13e5798d1'
    clientId       = 'H-YUC-00155d31bc02'
    clientType     = 'software'
    clientModel    = 'Yealink-USB-Connect'
    clientPlatform = 'windows'
  } | ConvertTo-Json -Compress
}
# en
$Object1 = Invoke-RestMethod @Params

# The endpoint returns 4.x version occasionally. Check the major version before proceeding.
if ($Object1.data.version.Split('.')[0] -ne '1') {
  $this.Log("The major version from the response is not 1: $($Object1.data.version)", 'Info')
  return
}

# Version
$this.CurrentState.Version = $Object1.data.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.file.url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.data.releaseDate | Get-Date | ConvertTo-UtcDateTime -Id UTC

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object1.data.releaseNote | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      # zh_CN
      $Object2 = Invoke-RestMethod @Params -Headers @{ language = 'zh_CN' }

      if ($this.CurrentState.Version -eq $Object2.data.version) {
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object2.data.releaseNote | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
