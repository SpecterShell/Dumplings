$Object1 = Invoke-RestMethod -Uri 'https://app-updates.agilebits.com/check/1/0/CLI2/en/2.0.0/N'

# Version
$this.CurrentState.Version = $Object1.available -eq '0' ? $this.LastState.Version: $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture        = 'x86'
  InstallerType       = 'zip'
  NestedInstallerType = 'portable'
  InstallerUrl        = "https://cache.agilebits.com/dist/1P/op2/pkg/v$($this.CurrentState.Version)/op_windows_386_v$($this.CurrentState.Version).zip"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture        = 'x64'
  InstallerType       = 'zip'
  NestedInstallerType = 'portable'
  InstallerUrl        = "https://cache.agilebits.com/dist/1P/op2/pkg/v$($this.CurrentState.Version)/op_windows_amd64_v$($this.CurrentState.Version).zip"
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
