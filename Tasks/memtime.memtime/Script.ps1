$Object1 = Invoke-RestMethod -Uri 'https://api.memtime.com/release/v2/app/latest-installers?updateChannel=stable&stage=production'
# x64
$Object2 = $Object1.installers.windows.Where({ $_.arch -eq 'x64' }, 'First')[0]
$VersionX64 = $Object2.version -replace '(?<=^|\.)0+(?=\d)'
# arm64
$Object3 = $Object1.installers.windows.Where({ $_.arch -eq 'arm64' }, 'First')[0]
$VersionARM64 = $Object3.version -replace '(?<=^|\.)0+(?=\d)'

if ($VersionX64 -ne $VersionARM64) {
  $this.Log("Inconsistent versions: x64: ${VersionX64}, arm64: ${VersionARM64}", 'Error')
  return
}

# Version
$this.CurrentState.Version = $VersionX64

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://releases.memtime.com/$($Object2.location)/$($Object2.installer)"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = "https://releases.memtime.com/$($Object3.location)/$($Object3.installer)"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.released_at | ConvertFrom-UnixTimeMilliseconds
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
