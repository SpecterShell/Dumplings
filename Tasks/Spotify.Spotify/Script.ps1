# https://github.com/amd64fox/LoaderSpot

$Object1 = Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/amd64fox/LoaderSpot/main/versions.json' | Read-ResponseContent | ConvertFrom-Json -AsHashtable

# Version
$this.CurrentState.Version = $Version = $Object1.Keys | Sort-Object -Property { $_ -creplace '\d+', { $_.Value.PadLeft(20) } } | Select-Object -Last 1

# RealVersion
$this.CurrentState.RealVersion = $Object1[$Version].fullversion

# Installer
# $this.CurrentState.Installer += [ordered]@{
#   Architecture = 'x86'
#   InstallerUrl = $Object1[$Version].links.win.x86
# }
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1[$Version].links.win.x64
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = $Object1[$Version].links.win.arm64
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
