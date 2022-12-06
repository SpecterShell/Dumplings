$Object = Invoke-RestMethod -Uri 'https://im.qq.com/rainbow/TIMDownload/' | Get-EmbeddedJson -StartsFrom 'var params= ' | ConvertFrom-Json

# Installer
$InstallerUrl = $Object.app.download.pcLink
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl
}

# Version
$Task.CurrentState.Version = [regex]::Match($InstallerUrl, '([\d\.]+)\.exe').Groups[1].Value

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object.app.download.pcDatetime | Get-Date -Format 'yyyy-MM-dd'

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
