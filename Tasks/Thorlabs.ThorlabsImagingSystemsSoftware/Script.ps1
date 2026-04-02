$Object1 = Invoke-WebRequest -Uri 'https://www.thorlabs.com/api/software_pages/check_updates?ItemID=ThorCam' | Read-ResponseContent | ConvertFrom-Xml

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.ItemID.SoftwarePkg.Where({ $_.DownloadLink.Contains('x86') }, 'First')[0].DownloadLink.Replace('//thin01mstroc282prod.dxcloud.episerver.net/', '//media.thorlabs.com/')
}
$VersionX86 = $Object1.ItemID.SoftwarePkg.Where({ $_.DownloadLink.Contains('x86') }, 'First')[0].VersionNumber

$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.ItemID.SoftwarePkg.Where({ $_.DownloadLink.Contains('x64') }, 'First')[0].DownloadLink.Replace('//thin01mstroc282prod.dxcloud.episerver.net/', '//media.thorlabs.com/')
}
$VersionX64 = $Object1.ItemID.SoftwarePkg.Where({ $_.DownloadLink.Contains('x64') }, 'First')[0].VersionNumber

if ($VersionX86 -ne $VersionX64) {
  $this.Log("x86 version: ${VersionX86}")
  $this.Log("x64 version: ${VersionX64}")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $VersionX64

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.ItemID.SoftwarePkg.Where({ $_.DownloadLink.Contains('x64') }, 'First')[0].ReleaseDate | Get-Date -Format 'yyyy-MM-dd'

      # LicenseUrl
      # $this.CurrentState.Locale += [ordered]@{
      #   Locale = 'en-US'
      #   Key    = 'LicenseUrl'
      #   Value  = "https://www.thorlabs.com/software/THO/ThorCam/ThorCam_V$($this.CurrentState.Version)/EULA.rtf"
      # }
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
