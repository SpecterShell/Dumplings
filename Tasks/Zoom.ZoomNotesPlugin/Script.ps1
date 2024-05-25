$Object1 = Invoke-RestMethod -Uri 'https://zoom.us/rest/download?os=win'

# Version
$this.CurrentState.Version = $Object1.result.downloadVO.notesPlugin.version

# RealVersion
$this.CurrentState.RealVersion = $this.CurrentState.Version.Split('.')[0..2] -join '.'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://zoom.us/client/$($this.CurrentState.Version)/$($Object1.result.downloadVO.notesPlugin.packageName)"
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
