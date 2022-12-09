$Response = Invoke-RestMethod -Uri 'https://www.kdocs.cn/kd/api/configure/list?idList=kdesktopVersion,autoDownload'

$Object1 = $Response.data.kdesktopVersion | ConvertFrom-Json
$Object2 = $Response.data.autoDownload | ConvertFrom-Json

# Version
$Task.CurrentState.Version = [regex]::Match($Object1.win, 'v([\d\.]+)').Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object2.kdesktopWin.1001
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
