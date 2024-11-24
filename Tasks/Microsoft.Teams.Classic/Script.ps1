$Object1 = (Invoke-RestMethod -Uri 'https://config.teams.microsoft.com/config/v1/MicrosoftTeams/27_1.0.0.0?environment=prod&agents=TeamsBuilds').TeamsBuilds.BuildSettings.Desktop

if (@(@('windows', 'windows64', 'arm64') | Sort-Object -Property { $Object1.$_.latestVersion } -Unique).Count -gt 1) {
  $this.Log("Windows x86 version: $($Object1.windows.latestVersion)")
  $this.Log("Windows x64 version: $($Object1.windows64.latestVersion)")
  $this.Log("Windows arm64 version: $($Object1.arm64.latestVersion)")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Object1.windows64.latestVersion

# Installer
$Prefix = 'https://statics.teams.cdn.office.net'
$this.CurrentState.Installer += [ordered]@{
  Architecture           = 'x86'
  InstallerType          = 'exe'
  InstallerUrl           = "${Prefix}/production-windows/$($Object1.windows.latestVersion)/Teams_windows.exe"
  AppsAndFeaturesEntries = @(
    [ordered]@{
      DisplayVersion = $this.CurrentState.Version
    }
  )
}
$this.CurrentState.Installer += [ordered]@{
  Architecture           = 'x64'
  InstallerType          = 'exe'
  InstallerUrl           = "${Prefix}/production-windows-x64/$($Object1.windows64.latestVersion)/Teams_windows_x64.exe"
  AppsAndFeaturesEntries = @(
    [ordered]@{
      DisplayVersion = $this.CurrentState.Version
    }
  )
}
$this.CurrentState.Installer += [ordered]@{
  Architecture           = 'arm64'
  InstallerType          = 'exe'
  InstallerUrl           = "${Prefix}/production-windows-arm64/$($Object1.arm64.latestVersion)/Teams_windows_arm64.exe"
  AppsAndFeaturesEntries = @(
    [ordered]@{
      DisplayVersion = $this.CurrentState.Version
    }
  )
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'wix'
  InstallerUrl  = "${Prefix}/production-windows/$($Object1.windows.latestVersion)/Teams_windows.msi"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = "${Prefix}/production-windows-x64/$($Object1.windows64.latestVersion)/Teams_windows_x64.msi"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'wix'
  InstallerUrl  = "${Prefix}/production-windows-arm64/$($Object1.arm64.latestVersion)/Teams_windows_arm64.msi"
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
