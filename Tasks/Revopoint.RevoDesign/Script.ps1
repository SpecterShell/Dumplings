$Object1 = Invoke-WebRequest -Uri 'https://www.quicksurface.com/updatecheck/revodesign8.txt' | Read-ResponseContent

if ($Object1 -notmatch '^\d+(?:\|\d+)+$') {
  $this.Log('The version from the response content is invalid', 'Error')
  return
}

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
