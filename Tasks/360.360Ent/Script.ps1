# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = Get-RedirectedUrls -Uri 'https://saas.browser.360.net/index/downPackage?os=windows' -Method GET | Select-Object -Last 1
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '_(\d+\.\d+\.\d+\.\d+)[_.]').Groups[1].Value

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
