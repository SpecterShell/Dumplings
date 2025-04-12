# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = Get-RedirectedUrls -Uri 'https://downloads.remarkable.com/latest/windows' -Method GET | Select-Object -Last 1
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '(\d+(?:\.\d+){3})').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Print()
    $this.Write()
  }
  'Updated' {
    $this.Message()
    $this.Submit()
  }
}
