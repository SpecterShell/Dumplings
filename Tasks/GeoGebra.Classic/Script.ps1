# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'exe'
  InstallerUrl  = $InstallerUrl = Get-RedirectedUrl -Uri 'https://download.geogebra.org/package/win-autoupdate'
}
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'wix'
  InstallerUrl  = $InstallerUrl -replace '\.exe$', '.msi'
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '-(\d+-\d+-\d+)').Groups[1].Value.Replace('-', '.')

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
