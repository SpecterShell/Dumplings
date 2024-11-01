$Object1 = Invoke-RestMethod -Uri 'https://config.teams.microsoft.com/config/v1/MicrosoftTeams/49_1.0.0.0?environment=prod&agents=TeamsBuilds'

if (@(@('x86', 'x64', 'arm64') | Sort-Object -Property { $Object1.TeamsBuilds.BuildSettings.WebView2Canary.$_.latestVersion } -Unique).Count -gt 1) {
  $this.Log("x86 version: $($Object1.TeamsBuilds.BuildSettings.WebView2Canary.x86.latestVersion)")
  $this.Log("x64 version: $($Object1.TeamsBuilds.BuildSettings.WebView2Canary.x64.latestVersion)")
  $this.Log("arm64 version: $($Object1.TeamsBuilds.BuildSettings.WebView2Canary.arm64.latestVersion)")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Object1.TeamsBuilds.BuildSettings.WebView2Canary.x64.latestVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.TeamsBuilds.BuildSettings.WebView2Canary.x86.buildLink
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.TeamsBuilds.BuildSettings.WebView2Canary.x64.buildLink
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = $Object1.TeamsBuilds.BuildSettings.WebView2Canary.arm64.buildLink
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
