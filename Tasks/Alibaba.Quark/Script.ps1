$Object1 = (Invoke-WebRequest -Uri 'https://www.quark.cn/').Content | Get-EmbeddedJson -StartsFrom 'window.__wh_data__ = ' | ConvertFrom-Json

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object1.page.'10005'.downloadConfig.downloadLink
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, 'V(\d+\.\d+\.\d+\.\d+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
