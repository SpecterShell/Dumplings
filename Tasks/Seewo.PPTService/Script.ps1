$Object1 = Invoke-RestMethod -Uri 'https://e.seewo.com/download/fromSeewoEdu?code=PPTService'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.downloadUrl
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '([\d\.]+)\.exe').Groups[1].Value

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
