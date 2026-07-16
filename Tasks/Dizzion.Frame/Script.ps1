$Object1 = Invoke-RestMethod -Uri 'https://prod-sup-5683567dcbd60804cb34.s3.amazonaws.com/Frame+App/latest.json'

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += $Installer = [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = "https://prod-sup-5683567dcbd60804cb34.s3.amazonaws.com/Frame+App/$($this.CurrentState.Version)/win32/x64/Frame.msi"
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
