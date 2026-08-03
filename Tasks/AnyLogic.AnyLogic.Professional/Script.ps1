$Object1 = $Global:DumplingsStorage.AnyLogicApps.BuildDescriptor.Build.Where({ $_.OS -eq 'win64' -and $_.Edition -eq 'Professional' }, 'First')[0]

# Version
$this.CurrentState.Version = $Object1.Version

# RealVersion
$this.CurrentState.Version = $this.CurrentState.Version.Split('.')[0..2] -join '.'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.URL
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
