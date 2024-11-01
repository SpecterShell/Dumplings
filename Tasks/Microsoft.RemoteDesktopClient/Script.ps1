# x86
$Object1 = Invoke-RestMethod -Uri 'https://go.microsoft.com/fwlink/?linkid=2099065'
# x64
$Object2 = Invoke-RestMethod -Uri 'https://go.microsoft.com/fwlink/?linkid=2098963'
# arm64
$Object3 = Invoke-RestMethod -Uri 'https://go.microsoft.com/fwlink/?linkid=2099066'

if (@(@($Object1, $Object2, $Object3) | Sort-Object -Property { $_.version } -Unique).Count -gt 1) {
  $this.Log("x86 version: $($Object1.version)")
  $this.Log("x64 version: $($Object2.version)")
  $this.Log("arm64 version: $($Object3.version)")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Object2.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object2.url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = $Object3.url
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
