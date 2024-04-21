$Object1 = Invoke-WebRequest -Uri 'https://g.live.com/1rewlive5skydrive/MsitSlowV2' | Read-ResponseContent | ConvertFrom-Xml | Select-Xml -XPath '/root/update' | Sort-Object -Property { [int]$_.Node.throttle } -Bottom 1 | Select-Object -ExpandProperty 'Node'

# Version
$this.CurrentState.Version = $Object1.currentversion

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.binary.url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.amd64binary.url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = $Object1.arm64binary.url
}

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
