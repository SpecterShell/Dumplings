$Prefix = 'https://antigravity-hub-auto-updater-974169037036.us-central1.run.app/manifest/'
# x64
$Object1 = Invoke-RestMethod -Uri "${Prefix}latest-x64-win.yml" | ConvertFrom-Yaml
$VersionX64 = $Object1.version
# arm64
$Object2 = Invoke-RestMethod -Uri "${Prefix}latest-arm-win.yml" | ConvertFrom-Yaml
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
  InstallerUrl = Join-Uri $Prefix $Object1.files[0].url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = Join-Uri $Prefix $Object2.files[0].url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.releaseDate | Get-Date -AsUTC
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

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
