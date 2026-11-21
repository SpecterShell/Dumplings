$Object1 = Invoke-RestMethod -Uri 'https://e.seewo.com/download/fromSeewoEdu?code=EasiCapsule'

# Version
$this.CurrentState.Version = $Object1.data.softVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.downloadUrl
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
