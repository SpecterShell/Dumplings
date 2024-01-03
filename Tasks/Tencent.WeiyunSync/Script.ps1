$Object1 = Invoke-RestMethod -Uri 'https://jsonschema.qpic.cn/2993ffb0f5d89de287319113301f3fca/179b0d35c9b088e5e72862a680864254/config'

# Version
$this.CurrentState.Version = $Object1.windows_sync.version

# RealVersion
$this.CurrentState.RealVersion = [regex]::Match($this.CurrentState.Version, '(\d+\.\d+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.windows_sync.download_url.Replace('dldir1.qq.com', 'dldir1v6.qq.com')
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.windows_sync.date | Get-Date -Format 'yyyy-MM-dd'

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
}
