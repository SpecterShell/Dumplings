$Object1 = Invoke-WebRequest -Uri 'https://download-electron.aircall.io/aircall-workspace/RELEASES' | Read-ResponseContent | ConvertFrom-SquirrelReleases | Where-Object -FilterScript { -not $_.IsDelta } | Sort-Object -Property { $_.Version -creplace '\d+', { $_.Value.PadLeft(20) } } -Bottom 1

# Version
$this.CurrentState.Version = $Object1.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture           = 'x64'
  InstallerType          = 'exe'
  InstallerUrl           = "https://download-electron.aircall.io/aircall-workspace/Aircall-Workspace-$($this.CurrentState.Version)-x64.exe"
  AppsAndFeaturesEntries = @(
    [ordered]@{
      DisplayName    = 'Aircall-Workspace'
      DisplayVersion = $this.CurrentState.Version
    }
  )
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = "https://download-electron.aircall.io/aircall-workspace/Aircall-Workspace-$($this.CurrentState.Version)-x64.msi"
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
