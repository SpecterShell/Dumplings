$Object = Invoke-RestMethod -Uri 'https://godbiao.com/api/getv/' -Headers @{
  origin = 'https://srf.xunfei.cn'
}

# Version
$Task.CurrentState.Version = [regex]::Match($Object[2], 'v([\d\.]+)').Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl -Uri 'https://srf.xunfei.cn/winpc/'
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
