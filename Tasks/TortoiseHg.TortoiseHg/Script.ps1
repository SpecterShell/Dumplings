$Object1 = Invoke-RestMethod -Uri 'https://www.mercurial-scm.org/release/tortoisehg/latest.dat' | ConvertFrom-Csv -Header @('Identifier', 'Version', 'Platform', 'InstallerUrl', 'Description') -Delimiter "`t"

$InstallerObjectX86 = $Object1 | Where-Object -FilterScript { $_.InstallerUrl.Contains('x86') -and $_.InstallerUrl.EndsWith('.msi') } | Sort-Object -Property { $_.Version -replace '\d+', { $_.Value.PadLeft(20) } } -Bottom 1
$InstallerObjectX64 = $Object1 | Where-Object -FilterScript { $_.InstallerUrl.Contains('x64') -and $_.InstallerUrl.EndsWith('.msi') } | Sort-Object -Property { $_.Version -replace '\d+', { $_.Value.PadLeft(20) } } -Bottom 1

if (@(@($InstallerObjectX86, $InstallerObjectX64) | Sort-Object -Property { $_.Version } -Unique).Count -gt 1) {
  $this.Log("x86 version: $($InstallerObjectX86.Version)")
  $this.Log("x64 version: $($InstallerObjectX64.Version)")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $InstallerObjectX64.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'wix'
  InstallerUrl  = $InstallerObjectX86.InstallerUrl
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = $InstallerObjectX64.InstallerUrl
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
