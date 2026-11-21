$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrlX64 = Get-RedirectedUrl -Uri 'https://sirius-release.lx.netease.com/api/pub/client/update/download-windows'
}

# Version
$this.CurrentState.Version = [regex]::Matches($InstallerUrlX64, '([\d\.]+)\.exe').Groups[-1].Value

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
