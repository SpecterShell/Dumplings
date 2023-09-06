$Param = @{
  Uri            = 'https://pcmanager.microsoft.com/config/api/v2/AppConfig'
  Method         = 'Post'
  Authentication = 'Bearer'
  Token          = ConvertTo-SecureString -String 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE5NzIyODI5MjIsImlzcyI6Imh0dHBzOi8vcGNtY29uZmlnLmNoaW5hY2xvdWRzaXRlcy5jbiIsImF1ZCI6Imh0dHBzOi8vcGNtY29uZmlnLmNoaW5hY2xvdWRzaXRlcy5jbiJ9.ZRyRbJdeCaXA4a5v6NyiJGOZATJ0ifxV_E8453SmYK4' -AsPlainText
  Body           = (
    @{
      RequestKeys = @('PCM:AutoUpdateOptions')
      Metadata    = @{
        '%Channel%'    = '10000'
        insiderAllowed = $true
      }
      Pattern     = '{}_{10000}'
      Encrypt     = $false
    } | ConvertTo-Json -Compress
  )
  ContentType    = 'application/json; charset=utf-8'
}
$Object = (Invoke-RestMethod @Param).results.'PCM:AutoUpdateOptions' | ConvertFrom-Json

# Version
$Task.CurrentState.Version = $Object.Version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl -Uri $Object.DownloadLink
}

# ReleaseNotes (en-US)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotes'
  Value  = ($Object.UpdateInfoEx.en | ConvertFrom-Json).details | Format-Text
}
# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = ($Object.UpdateInfoEx.'zh-cn' | ConvertFrom-Json).details | Format-Text
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
