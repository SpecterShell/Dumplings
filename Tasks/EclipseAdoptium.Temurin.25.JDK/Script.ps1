$Object1 = (Invoke-WebRequest -Uri 'https://api.adoptium.net/v3/assets/latest/25/hotspot?image_type=jdk&os=windows').Content | ConvertFrom-Json -AsHashtable

# x64
$Object2 = $Object1 | Where-Object -FilterScript { $_.binary.architecture -eq 'x64' } | Select-Object -First 1
$VersionX64 = "$($Object2.version.major).$($Object2.version.minor).$($Object2.version.security).$(($Object2.version.Contains('patch') ? $Object2.version.patch * 100 : 0) + $Object2.version.build)"

# # arm64
# $Object3 = $Object1 | Where-Object -FilterScript { $_.binary.architecture -eq 'aarch64' } | Select-Object -First 1
# $VersionArm64 = "$($Object3.version.major).$($Object3.version.minor).$($Object3.version.security).$(($Object3.version.Contains('patch') ? $Object3.version.patch * 100 : 0) + $Object3.version.build)"

# if ($VersionX64 -ne $VersionArm64) {
#   $this.Log("x64 version: ${VersionX64}")
#   $this.Log("arm64 version: ${VersionArm64}")
#   throw 'Inconsistent versions detected'
# }

# Version
$this.CurrentState.Version = $VersionX64

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object2.binary.installer.link | ConvertTo-UnescapedUri
}
# $this.CurrentState.Installer += [ordered]@{
#   Architecture = 'arm64'
#   InstallerUrl = $Object3.binary.installer.link | ConvertTo-UnescapedUri
# }

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.binary.updated_at.ToUniversalTime()

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $Object2.release_link | ConvertTo-UnescapedUri
      }
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
