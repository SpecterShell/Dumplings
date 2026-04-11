$Object1 = Invoke-WebRequest -Uri 'http://www.quicksurface.com/updatecheck/revodesign8.txt' | Read-ResponseContent

# Version
$this.CurrentState.Version = $Object1.Replace('|', '.').Trim()

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'msi'
  InstallerUrl  = "https://www.quicksurface.com/download/revodesign/RevoDesignSetup_x64_$($this.CurrentState.Version.Split('.')[0..2] -join '').msi"
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
