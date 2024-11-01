$Object1 = Invoke-RestMethod -Uri 'https://www.mercurial-scm.org/release/windows/latest.dat' | ConvertFrom-Csv -Header @('Identifier', 'Version', 'Platform', 'InstallerUrl', 'Description') -Delimiter "`t"

if (@($Object1.Version | Sort-Object -Unique).Count -gt 1) {
  $this.Log("Versions: $($Object1.Version | Sort-Object -Unique | Join-String -Separator ', ')")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Object1.Version | Sort-Object -Property { $_ -replace '\d+', { $_.Value.PadLeft(20) } } -Bottom 1

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'inno'
  InstallerUrl  = $Object1.Where({ $_.InstallerUrl.Contains('x86') -and $_.InstallerUrl.EndsWith('.exe') }, 'Last')[-1].InstallerUrl
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'inno'
  InstallerUrl  = $Object1.Where({ $_.InstallerUrl.Contains('x64') -and $_.InstallerUrl.EndsWith('.exe') }, 'Last')[-1].InstallerUrl
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'wix'
  InstallerUrl  = $Object1.Where({ $_.InstallerUrl.Contains('x86') -and $_.InstallerUrl.EndsWith('.msi') }, 'Last')[-1].InstallerUrl
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = $Object1.Where({ $_.InstallerUrl.Contains('x64') -and $_.InstallerUrl.EndsWith('.msi') }, 'Last')[-1].InstallerUrl
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
