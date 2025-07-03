$Object1 = $Global:DumplingsStorage.SonicWallApps.Where({ $_.Count -ge 2 -and $_[1] -is [string] -and $_[1].Contains('ConnectTunnel') -and $_[1].Contains('.exe') }, 'First')[0][1] -replace '^[a-zA-Z0-9]+:I?'
$Object2 = [Newtonsoft.Json.Linq.JArray]::Parse($Object1)

# x86
$Object3 = $Object2.SelectTokens('$..cta_group[?(@.link.href =~ /ConnectTunnel_x86.+\.exe$/)]').Where({ $true }, 'First')[0].ToString() | ConvertFrom-Json
$InstallerX86Url = $Object3.link.href
$VersionX86 = [regex]::Matches($InstallerX86Url, '(\d+(?:\.\d+)+)')[-1].Groups[1].Value

# x64
$Object4 = $Object2.SelectTokens('$..cta_group[?(@.link.href =~ /ConnectTunnel_x64.+\.exe$/)]').Where({ $true }, 'First')[0].ToString() | ConvertFrom-Json
$InstallerX64Url = $Object4.link.href
$VersionX64 = [regex]::Matches($InstallerX64Url, '(\d+(?:\.\d+)+)')[-1].Groups[1].Value

# arm64
$Object5 = $Object2.SelectTokens('$..cta_group[?(@.link.href =~ /ConnectTunnel_arm64.+\.exe$/)]').Where({ $true }, 'First')[0].ToString() | ConvertFrom-Json
$InstallerARM64Url = $Object5.link.href
$VersionARM64 = [regex]::Matches($InstallerARM64Url, '(\d+(?:\.\d+)+)')[-1].Groups[1].Value

if (@(@($VersionX86, $VersionX64, $VersionARM64) | Sort-Object -Unique).Count -gt 1) {
  $this.Log("x86 version: ${VersionX86}")
  $this.Log("x64 version: ${VersionX64}")
  $this.Log("arm64 version: ${VersionARM64}")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $VersionX64

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $InstallerX86Url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerX64Url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = $InstallerARM64Url
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
