# x86
$Object1 = Invoke-RestMethod -Uri 'https://download.snapform.com/redirect/sf_upgrade_1_6.php?os=exe' | Split-LineEndings
$VersionX86 = $Object1[0].Trim()
# x64
$Object2 = Invoke-RestMethod -Uri 'https://download.snapform.com/redirect/sf_upgrade_1_6.php?os=exe64' | Split-LineEndings
$VersionX64 = $Object2[0].Trim()

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
  InstallerUrl = $Object1[1].Trim() | ConvertTo-Https
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object2[1].Trim() | ConvertTo-Https
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
