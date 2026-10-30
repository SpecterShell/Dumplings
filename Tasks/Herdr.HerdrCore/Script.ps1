$Object1 = Invoke-RestMethod -Uri 'https://releases.herdr.dev/core/latest.json'

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture        = 'x64'
  InstallerType       = 'zip'
  NestedInstallerType = 'portable'
  InstallerUrl        = $Object1.targets.'windows-x86_64'.url
  InstallerSha256     = $Object1.targets.'windows-x86_64'.sha256.ToUpper()
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
