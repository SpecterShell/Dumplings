$Object1 = $Global:DumplingsStorage.SonicWallApps.Where({ $_.Count -ge 2 -and $_[1] -is [string] -and $_[1].Contains('NetExtender') -and $_[1].Contains('.msi') }, 'Last')[0][1] -replace '^[a-zA-Z0-9]+:I?'
$Object2 = [Newtonsoft.Json.Linq.JArray]::Parse($Object1)

# x86 MSI
$Object3 = $Object2.SelectTokens('$..cta_group[?(@.link.href =~ /NetExtender-x86.+\.msi/)]').Where({ $true }, 'Last')[0].ToString() | ConvertFrom-Json
$InstallerX86MSIUrl = $Object3.link.href.Trim()
$VersionX86MSI = [regex]::Match($InstallerX86MSIUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

# x64 MSI
$Object4 = $Object2.SelectTokens('$..cta_group[?(@.link.href =~ /NetExtender-x64.+\.msi/)]').Where({ $true }, 'Last')[0].ToString() | ConvertFrom-Json
$InstallerX64MSIUrl = $Object4.link.href.Trim()
$VersionX64MSI = [regex]::Match($InstallerX64MSIUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

# arm64 MSI
$Object5 = $Object2.SelectTokens('$..cta_group[?(@.link.href =~ /NetExtender-arm64.+\.msi/)]').Where({ $true }, 'Last')[0].ToString() | ConvertFrom-Json
$InstallerARM64MSIUrl = $Object5.link.href.Trim()
$VersionARM64MSI = [regex]::Match($InstallerARM64MSIUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

# x86 EXE
$Object6 = $Object2.SelectTokens('$..cta_group[?(@.link.href =~ /NXSetupU-x86.+\.exe/)]').Where({ $true }, 'Last')[0].ToString() | ConvertFrom-Json
$InstallerX86EXEUrl = $Object6.link.href.Trim()
$VersionX86EXE = [regex]::Match($InstallerX86EXEUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

# x64 EXE
$Object7 = $Object2.SelectTokens('$..cta_group[?(@.link.href =~ /NXSetupU-x64.+\.exe/)]').Where({ $true }, 'Last')[0].ToString() | ConvertFrom-Json
$InstallerX64EXEUrl = $Object7.link.href.Trim()
$VersionX64EXE = [regex]::Match($InstallerX64EXEUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

# arm64 EXE
# $Object8 = $Object2.SelectTokens('$..cta_group[?(@.link.href =~ /NXSetupU-arm64.+\.exe/)]').Where({ $true }, 'Last')[0].ToString() | ConvertFrom-Json
# $InstallerARM64EXEUrl = $Object8.link.href.Trim()
# $VersionARM64EXE = [regex]::Match($InstallerARM64EXEUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

# if (@(@($VersionX86MSI, $VersionX64MSI, $VersionARM64MSI, $VersionX86EXE, $VersionX64EXE, $VersionARM64EXE) | Sort-Object -Unique).Count -gt 1) {
if (@(@($VersionX86MSI, $VersionX64MSI, $VersionARM64MSI, $VersionX86EXE, $VersionX64EXE) | Sort-Object -Unique).Count -gt 1) {
  $this.Log("x86 MSI version: ${VersionX86MSI}")
  $this.Log("x64 MSI version: ${VersionX64MSI}")
  $this.Log("arm64 MSI version: ${VersionARM64MSI}")
  $this.Log("x86 EXE version: ${VersionX86EXE}")
  $this.Log("x64 EXE version: ${VersionX64EXE}")
  # $this.Log("arm64 EXE version: ${VersionARM64EXE}")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $VersionX64MSI

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'wix'
  InstallerUrl  = $InstallerX86MSIUrl
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = $InstallerX64MSIUrl
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'wix'
  InstallerUrl  = $InstallerARM64MSIUrl
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'nullsoft'
  InstallerUrl  = $InstallerX86EXEUrl
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = $InstallerX64EXEUrl
}
# $this.CurrentState.Installer += [ordered]@{
#   Architecture  = 'arm64'
#   InstallerType = 'nullsoft'
#   InstallerUrl  = $InstallerARM64EXEUrl
# }

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
