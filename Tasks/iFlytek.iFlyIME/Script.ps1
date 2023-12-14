$Object = Invoke-RestMethod -Uri 'https://godbiao.com/api/getv/' -Headers @{
  origin = 'https://srf.xunfei.cn'
}

# Version
$Task.CurrentState.Version = [regex]::Match($Object.2 ?? $Object[2], 'v([\d\.]+)').Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl -Uri 'https://srf.xunfei.cn/winpc/'
}

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 }) {
    $Task.Submit()
  }
}
