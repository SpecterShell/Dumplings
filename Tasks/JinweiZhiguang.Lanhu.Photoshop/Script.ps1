$Object = Invoke-RestMethod -Uri 'https://lanhuapp.com/api/project/app_version?apptype=lanhu_ps_windows'

# Installer
$InstallerUrl = $Object.result.url
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl
}

# Version
$Task.CurrentState.Version = [regex]::Match($InstallerUrl, '(\d+\.\d+\.\d+)').Groups[1].Value

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object.result.create_time | Get-Date

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
