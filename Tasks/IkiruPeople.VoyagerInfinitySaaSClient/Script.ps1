# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl1st -Uri 'https://live.vslcloud.com/GetLatest' -Method GET
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

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
