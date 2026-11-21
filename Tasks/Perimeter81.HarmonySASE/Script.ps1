$Object1 = Invoke-WebRequest -Uri 'https://sc1.checkpoint.com/documents/Infinity_Portal/WebAdminGuides/EN/SASE-Admin-Guide/SASE_Security/Topics/introduction/supported_devices_and_operating_systems.html'

# Installer
$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.Links.Where({ try { $_.href.EndsWith('.msi') -and -not $_.href.Contains('arm64') } catch {} }, 'First')[0].href
}
$VersionX64 = [regex]::Match($InstallerX64.InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

$this.CurrentState.Installer += $InstallerARM64 = [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = $Object1.Links.Where({ try { $_.href.EndsWith('.msi') -and $_.href.Contains('arm64') } catch {} }, 'First')[0].href
}
$VersionARM64 = [regex]::Match($InstallerARM64.InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

if ($VersionX64 -ne $VersionARM64) {
  $this.Log("Inconsistent versions: x64: ${VersionX64}, arm64: ${VersionARM64}", 'Error')
  return
}

# Version
$this.CurrentState.Version = $VersionX64

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
