# x64
$Object1 = Invoke-RestMethod -Uri 'https://antigravity-cli-auto-updater-974169037036.us-central1.run.app/manifests/windows_amd64.json'
$VersionX64 = $Object1.version
# arm64
$Object2 = Invoke-RestMethod -Uri 'https://antigravity-cli-auto-updater-974169037036.us-central1.run.app/manifests/windows_arm64.json'
$VersionArm64 = $Object2.version

if ($VersionX64 -ne $VersionArm64) {
  $this.Log("Inconsistent versions: x64: ${VersionX64}, arm64: ${VersionArm64}", 'Error')
  return
}

# Version
$this.CurrentState.Version = $VersionX64

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = $Object2.url
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
