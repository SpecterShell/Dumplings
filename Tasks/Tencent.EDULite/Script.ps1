$Object = Invoke-RestMethod -Uri 'https://sas.qq.com/cgi-bin/ke_download_speed'

# Installer
$InstallerUrl = $Object.result.win.download_url
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl
}

# Version
$Task.CurrentState.Version = [regex]::Match($InstallerUrl, 'EduLiteInstall_([\d\.]+)_.+\.exe').Groups[1].Value

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
