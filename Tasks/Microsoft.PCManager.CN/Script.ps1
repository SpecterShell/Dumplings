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
$Object1 = (Invoke-RestMethod @Param).results.'PCM:AutoUpdateOptions' | ConvertFrom-Json

# Version
$this.CurrentState.Version = $Object1.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.DownloadLink
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      if (-not [string]::IsNullOrWhiteSpace($Object1.UpdateInfoEx.en)) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = ($Object1.UpdateInfoEx.en | ConvertFrom-Json).details | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      if (-not [string]::IsNullOrWhiteSpace($Object1.UpdateInfoEx.'zh-cn')) {
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = ($Object1.UpdateInfoEx.'zh-cn' | ConvertFrom-Json).details | Format-Text
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
