# x64
$Object1 = Invoke-RestMethod -Uri 'https://cloud-api.yandex.net/v1/disk/clients/win64/installer'

# x86
$Object2 = Invoke-RestMethod -Uri 'https://cloud-api.yandex.net/v1/disk/clients/win86/installer'

if (@(@($Object1, $Object2) | Sort-Object -Property { $_.version } -Unique).Count -gt 1) {
  $this.Log("x86 version: $($Object2.version)")
  $this.Log("x64 version: $($Object1.version)")
  throw 'Distinct versions detected'
}

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object2.file
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.file
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
