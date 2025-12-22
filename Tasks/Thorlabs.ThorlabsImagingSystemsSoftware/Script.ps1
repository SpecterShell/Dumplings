$Object1 = Invoke-WebRequest -Uri 'https://www.thorlabs.com/software_pages/check_updates.cfm?ItemID=ThorCam' | Read-ResponseContent | ConvertFrom-Xml

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $InstallerX86Url = $Object1.ItemID.SoftwarePkg.Where({ $_.DownloadLink.Contains('x86') }, 'First')[0].DownloadLink
}
$VersionX86 = [regex]::Match($InstallerX86Url, '(\d+(\.\d+)+)').Groups[1].Value

$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerX64Url = $Object1.ItemID.SoftwarePkg.Where({ $_.DownloadLink.Contains('x64') }, 'First')[0].DownloadLink
}
$VersionX64 = [regex]::Match($InstallerX64Url, '(\d+(\.\d+)+)').Groups[1].Value

if ($VersionX86 -ne $VersionX64) {
  $this.Log("x86 version: ${VersionX86}")
  $this.Log("x64 version: ${VersionX64}")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $VersionX64

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
