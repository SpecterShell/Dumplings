# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $InstallerUrlX86 = Get-RedirectedUrl -Uri 'https://sirius-release.lx.netease.com/api/pub/client/update/download-win32'
}
$VersionX86 = [regex]::Matches($InstallerUrlX86, '([\d\.]+)\.exe').Groups[-1].Value

$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrlX64 = Get-RedirectedUrl -Uri 'https://sirius-release.lx.netease.com/api/pub/client/update/download-windows'
}
$VersionX64 = [regex]::Matches($InstallerUrlX64, '([\d\.]+)\.exe').Groups[-1].Value

# Version
$this.CurrentState.Version = $VersionX64

$Identical = $true
if ($VersionX86 -ne $VersionX64) {
  $this.Logging('Distinct versions detected', 'Warning')
  $Identical = $false
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 -and $Identical }) {
    $this.Submit()
  }
}
