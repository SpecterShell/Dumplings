$Object1 = Invoke-RestMethod -Uri 'https://cloud.xylink.com/api/rest/en/version?platform=desktop_pc'

# Version
$this.CurrentState.Version = $Object1.versionName

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.appUrl | Split-Uri -LeftPart 'Path'
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
