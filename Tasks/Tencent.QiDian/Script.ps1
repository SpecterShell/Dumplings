$Object = (Invoke-RestMethod -Uri 'https://qidian.qq.com/store/qd_interface/Download.php').data | Where-Object -Property 'FPlatform' -EQ -Value '1'

# Installer
$InstallerUrl = $Object.FUrl
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl
}

# Version
$Task.CurrentState.Version = [regex]::Match($InstallerUrl, '(\d+\.\d+\.\d+\.\d+)').Groups[1].Value

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object.FReleaseTime | Get-Date -Format 'yyyy-MM-dd'

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
