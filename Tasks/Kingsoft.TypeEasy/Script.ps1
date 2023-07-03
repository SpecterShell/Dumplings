$Object = (Invoke-RestMethod -Uri 'https://rubik.wps.cn/rubik-service/project/deploy?position=51dzt').data.project_components.Where({ $_.Name -eq 'dzt-banner' })[0].user_props

# Version
$Task.CurrentState.Version = [regex]::Match($Object.downloadVersion, '（([\d\.]+)）').Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = (($Object.download | ConvertFrom-Json).event | Where-Object({ $_.type -eq 'openLink' })).params.url
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = [regex]::Match($Object.downloadVersion, '(\d{4}\.\d{1,2}\.\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

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
