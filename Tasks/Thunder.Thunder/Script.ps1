$Object1 = Invoke-WebRequest -Uri 'https://dl.xunlei.com/'

# Version
$this.CurrentState.Version = [regex]::Match($Object1.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href.Contains('XunLei') } catch {} }, 'First')[0].href, '(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://down.sandai.net/thunder11/XunLeiSetup$($this.CurrentState.Version).exe"
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
