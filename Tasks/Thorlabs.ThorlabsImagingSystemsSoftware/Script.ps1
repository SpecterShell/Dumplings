$Object1 = Invoke-RestMethod -Uri 'https://www.thorlabs.com/software_pages/check_updates.cfm?ItemID=ThorCam'
# x86
$Object2 = $Object1.ItemID.SoftwarePkg.Where({ $_.DownloadLink.Contains('x86') }, 'First')[0]
$VersionX86 = $Object2.VersionNumber
# x64
$Object3 = $Object1.ItemID.SoftwarePkg.Where({ $_.DownloadLink.Contains('x64') }, 'First')[0]
$VersionX64 = $Object3.VersionNumber

if ($VersionX86 -ne $VersionX64) {
  $this.Log("x86 version: ${VersionX86}")
  $this.Log("x64 version: ${VersionX64}")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $VersionX64

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object2.DownloadLink
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object3.DownloadLink
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.ReleaseDate | Get-Date -Format 'yyyy-MM-dd'

      # LicenseUrl
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'LicenseUrl'
        Value  = "https://www.thorlabs.com/software/THO/ThorCam/ThorCam_V$($this.CurrentState.Version)/EULA.rtf"
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
