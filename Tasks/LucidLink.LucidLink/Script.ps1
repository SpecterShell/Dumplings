$Prefix = 'https://releases.lucidlink.com/prod/win/'

$Object1 = Invoke-RestMethod -Uri "${Prefix}installer.json"

# Version
$this.CurrentState.Version = "$($Object1.version.major).$($Object1.version.minor).$($Object1.version.build)"

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Prefix $Object1.installerFile
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
