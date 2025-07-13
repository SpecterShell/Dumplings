# x64
$Object1 = Invoke-WebRequest -Uri 'https://storage.googleapis.com/osprey-downloads-c02f6a0d-347c-492b-a752-3e0651722e97/nest-win-x64/RELEASES' | Read-ResponseContent | ConvertFrom-SquirrelReleases | Where-Object -FilterScript { -not $_.IsDelta } | Sort-Object -Property { $_.Version -creplace '\d+', { $_.Value.PadLeft(20) } } -Bottom 1

# arm64
$Object2 = Invoke-WebRequest -Uri 'https://storage.googleapis.com/osprey-downloads-c02f6a0d-347c-492b-a752-3e0651722e97/nest-win-arm64/RELEASES' | Read-ResponseContent | ConvertFrom-SquirrelReleases | Where-Object -FilterScript { -not $_.IsDelta } | Sort-Object -Property { $_.Version -creplace '\d+', { $_.Value.PadLeft(20) } } -Bottom 1

if ($Object1.Version -ne $Object2.Version) {
  $this.Log("Inconsistent versions: x64: $($Object1.Version), arm64: $($Object2.Version)", 'Error')
  return
}

# Version
$this.CurrentState.Version = $Object1.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = 'https://storage.googleapis.com/osprey-downloads-c02f6a0d-347c-492b-a752-3e0651722e97/nest-win-x64/Claude-Setup-x64.exe'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = 'https://storage.googleapis.com/osprey-downloads-c02f6a0d-347c-492b-a752-3e0651722e97/nest-win-arm64/Claude-Setup-arm64.exe'
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
