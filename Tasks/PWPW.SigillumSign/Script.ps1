# Installer
$this.CurrentState.Installer += $InstallerX86 = [ordered]@{
  Architecture = 'x86'
  InstallerUrl = Join-Uri $Global:DumplingsStorage.PWPWDownloadPagePrefix $Global:DumplingsStorage.PWPWDownloadPage.Links.Where({ try { $_.href -match 'Sigillum_[\d.]+_x86\.msi$' } catch {} }, 'First')[0].href
}
$VersionX86 = [regex]::Match($InstallerX86.InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Join-Uri $Global:DumplingsStorage.PWPWDownloadPagePrefix $Global:DumplingsStorage.PWPWDownloadPage.Links.Where({ try { $_.href -match 'Sigillum_[\d.]+_x64\.msi$' } catch {} }, 'First')[0].href
}
$VersionX64 = [regex]::Match($InstallerX64.InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

if ($VersionX86 -ne $VersionX64) {
  $this.Log("Inconsistent versions: x64: ${VersionX86}, arm64: ${VersionX64}", 'Error')
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
