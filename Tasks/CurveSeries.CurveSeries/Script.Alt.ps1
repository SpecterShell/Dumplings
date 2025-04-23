$Object1 = Invoke-RestMethod -Uri 'http://www.c3excel.com/datalink/Version.html'

# Version
$this.CurrentState.Version = [regex]::Match($Object1, '\[version\](\d+(?:\.\d+)+)\[/version\]').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://www.c3excel.com/datalink/Downloads/curveseries$($this.CurrentState.Version).exe"
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
