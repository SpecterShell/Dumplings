$Light = $false

$Object1 = (Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/slproweb/opensslhashes/refs/heads/master/win32_openssl_hashes.json').Content | ConvertFrom-Json -AsHashtable

# x86 EXE
$Object2 = $Object1.files.Values.Where({ $_.arch -eq 'INTEL' -and $_.bits -eq 32 -and $_.installer -eq 'exe' -and $_.light -eq $Light }, 'Last')[-1]
# x64 EXE
$Object3 = $Object1.files.Values.Where({ $_.arch -eq 'INTEL' -and $_.bits -eq 64 -and $_.installer -eq 'exe' -and $_.light -eq $Light }, 'Last')[-1]
# arm64 EXE
$Object4 = $Object1.files.Values.Where({ $_.arch -eq 'ARM' -and $_.bits -eq 64 -and $_.installer -eq 'exe' -and $_.light -eq $Light }, 'Last')[-1]
# x86 MSI
$Object5 = $Object1.files.Values.Where({ $_.arch -eq 'INTEL' -and $_.bits -eq 32 -and $_.installer -eq 'msi' -and $_.light -eq $Light }, 'Last')[-1]
# x64 MSI
$Object6 = $Object1.files.Values.Where({ $_.arch -eq 'INTEL' -and $_.bits -eq 64 -and $_.installer -eq 'msi' -and $_.light -eq $Light }, 'Last')[-1]
# arm64 MSI
$Object7 = $Object1.files.Values.Where({ $_.arch -eq 'ARM' -and $_.bits -eq 64 -and $_.installer -eq 'msi' -and $_.light -eq $Light }, 'Last')[-1]

if (@(@($Object2, $Object3, $Object4, $Object5, $Object6, $Object7) | Sort-Object -Property { "$($_.basever)$($_.subver)" } -Unique).Count -gt 1) {
  $this.Log("x86 EXE version: $($Object2.basever)")
  $this.Log("x64 EXE version: $($Object3.basever)")
  $this.Log("arm64 EXE version: $($Object4.basever)")
  $this.Log("x86 MSI version: $($Object5.basever)")
  $this.Log("x64 MSI version: $($Object6.basever)")
  $this.Log("arm64 MSI version: $($Object7.basever)")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = "$($Object3.basever)$($Object3.subver)"

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture    = 'x86'
  InstallerType   = 'inno'
  InstallerUrl    = $Object2.url
  InstallerSha256 = $Object2.sha256.ToUpper()
}
$this.CurrentState.Installer += [ordered]@{
  Architecture    = 'x64'
  InstallerType   = 'inno'
  InstallerUrl    = $Object3.url
  InstallerSha256 = $Object3.sha256.ToUpper()
}
$this.CurrentState.Installer += [ordered]@{
  Architecture    = 'arm64'
  InstallerType   = 'inno'
  InstallerUrl    = $Object4.url
  InstallerSha256 = $Object4.sha256.ToUpper()
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'wix'
  InstallerUrl  = $Object5.url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = $Object6.url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'wix'
  InstallerUrl  = $Object7.url
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
