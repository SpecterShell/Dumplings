$Object1 = (Invoke-WebRequest -Uri 'https://www.quark.cn/').Content | Get-EmbeddedJson -StartsFrom 'window.__wh_data__ = ' | ConvertFrom-Json

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object1.page.'10005'.downloadConfig.downloadLink
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, 'V(\d+\.\d+\.\d+\.\d+)').Groups[1].Value

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Print()
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
