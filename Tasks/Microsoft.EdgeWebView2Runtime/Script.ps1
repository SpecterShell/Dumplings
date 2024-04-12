$Object1 = Invoke-WebRequest -Uri 'https://developer.microsoft.com/en-us/microsoft-edge/webview2/' | ConvertFrom-Html

# Version
$this.CurrentState.Version = $Object1.SelectSingleNode('//button[@id="version"]/span').InnerText.Trim()

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = Get-RedirectedUrl -Uri 'https://go.microsoft.com/fwlink/?linkid=2099617'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Get-RedirectedUrl -Uri 'https://go.microsoft.com/fwlink/?linkid=2124701'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = Get-RedirectedUrl -Uri 'https://go.microsoft.com/fwlink/?linkid=2099616'
}

switch -Regex ($this.Check()) {
  'New' {
    $this.Print()
    $this.Write()
  }
  'Updated' {
    if (Compare-Object -ReferenceObject $this.LastState.Installer.InstallerUrl -DifferenceObject $this.CurrentState.Installer.InstallerUrl -IncludeEqual -ExcludeDifferent) {
      throw 'Not all installers have been updated'
    } else {
      $this.Write()
      $this.Message()
      $this.Submit()
    }
  }
}
