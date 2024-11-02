# x64
$Object1 = Invoke-RestMethod -Uri 'https://storage.googleapis.com/osprey-downloads-c02f6a0d-347c-492b-a752-3e0651722e97/nest-win-x64/RELEASES'
$VersionX64 = [regex]::Match($Object1.Split(' ')[1], 'AnthropicClaude-(\d+(?:\.\d+)+)-full').Groups[1].Value

# arm64
$Object2 = Invoke-RestMethod -Uri 'https://storage.googleapis.com/osprey-downloads-c02f6a0d-347c-492b-a752-3e0651722e97/nest-win-arm64/RELEASES'
$VersionArm64 = [regex]::Match($Object2.Split(' ')[1], 'AnthropicClaude-(\d+(?:\.\d+)+)-full').Groups[1].Value

if ($VersionX64 -ne $VersionArm64) {
  $this.Log("x64 version: ${VersionX64}")
  $this.Log("arm64 version: ${VersionArm64}")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $VersionX64

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
