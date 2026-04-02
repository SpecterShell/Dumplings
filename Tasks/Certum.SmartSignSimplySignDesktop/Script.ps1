$Object1 = Invoke-WebRequest -Uri 'https://support.certum.eu/en/software/procertum-smartsign/'

# Installer
# $this.CurrentState.Installer += $InstallerENX86 = [ordered]@{
#   InstallerLocale = 'en'
#   Architecture    = 'x86'
#   InstallerUrl    = $Object1.Links.Where({ try { $_.href.EndsWith('.msi') -and $_.href.Contains('32-bit') } catch {} }, 'First')[0].href
# }
# $VersionENX86 = [regex]::Match($InstallerENX86.InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

$this.CurrentState.Installer += $InstallerENX64 = [ordered]@{
  InstallerLocale = 'en'
  Architecture    = 'x64'
  InstallerUrl    = $Object1.Links.Where({ try { $_.href.EndsWith('.msi') -and $_.href.Contains('64-bit') } catch {} }, 'First')[0].href
}
$VersionENX64 = [regex]::Match($InstallerENX64.InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

$Object2 = Invoke-WebRequest -Uri 'https://pomoc.certum.pl/pl/oprogramowanie/procertum-smartsign/'

# Installer
# $this.CurrentState.Installer += $InstallerPLX86 = [ordered]@{
#   InstallerLocale = 'pl'
#   Architecture    = 'x86'
#   InstallerUrl    = $Object2.Links.Where({ try { $_.href.EndsWith('.msi') -and $_.href.Contains('32-bit') } catch {} }, 'First')[0].href
# }
# $VersionPLX86 = [regex]::Match($InstallerPLX86.InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

$this.CurrentState.Installer += $InstallerPLX64 = [ordered]@{
  InstallerLocale = 'pl'
  Architecture    = 'x64'
  InstallerUrl    = $Object2.Links.Where({ try { $_.href.EndsWith('.msi') -and $_.href.Contains('64-bit') } catch {} }, 'First')[0].href
}
$VersionPLX64 = [regex]::Match($InstallerPLX64.InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

# if (@(@($VersionENX86, $VersionENX64, $VersionPLX86, $VersionPLX64) | Sort-Object -Unique).Count -gt 1) {
#   $this.Log("Inconsistent versions: en-x86: ${VersionENX86}, en-x64: ${VersionENX64}, pl-x86: ${VersionPLX86}, pl-x64: ${VersionPLX64}", 'Error')
#   return
# }
if ($VersionENX64 -ne $VersionPLX64) {
  $this.Log("Inconsistent versions: en-x64: ${VersionENX64}, pl-x64: ${VersionPLX64}", 'Error')
  return
}

# Version
$this.CurrentState.Version = $VersionENX64

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
