$Object = Invoke-RestMethod -Uri 'https://jsonschema.qpic.cn/2993ffb0f5d89de287319113301f3fca/179b0d35c9b088e5e72862a680864254/config'

# Version
$Task.CurrentState.Version = $Object.windows_sync.version

# RealVersion
$Task.CurrentState.RealVersion = [regex]::Match($Task.CurrentState.Version, '(\d+\.\d+)').Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.windows_sync.download_url.Replace('dldir1.qq.com', 'dldir1v6.qq.com')
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object.windows_sync.date | Get-Date -Format 'yyyy-MM-dd'

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
}
