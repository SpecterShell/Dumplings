# x86
$Object1 = $Global:DumplingsStorage.ArgenteX86.data.Where({ $_.name -eq 'Argente Startup Manager' -and $_.installer -eq 'startupmanagerx86' }, 'First')[0]
# x64
$Object2 = $Global:DumplingsStorage.ArgenteX64.data.Where({ $_.name -eq 'Argente Startup Manager' -and $_.installer -eq 'startupmanagerx64' }, 'First')[0]
# arm64
$Object3 = $Global:DumplingsStorage.ArgenteARM64.data.Where({ $_.name -eq 'Argente Startup Manager' -and $_.installer -eq 'startupmanagerarm64' }, 'First')[0]

if (@(@($Object1.version, $Object2.version, $Object3.version) | Sort-Object -Unique).Count -gt 1) {
  $this.Log("Inconsistent versions: x86: $($Object1.version), x64: $($Object2.version), arm64: $($Object3.version)", 'Error')
  return
}

# Version
$this.CurrentState.Version = $Object2.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'inno'
  InstallerUrl  = 'https://argenteutilities.com/en/download/startupmanagerx86'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'inno'
  InstallerUrl  = 'https://argenteutilities.com/en/download/startupmanagerx64'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'inno'
  InstallerUrl  = 'https://argenteutilities.com/en/download/startupmanagerarm64'
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
