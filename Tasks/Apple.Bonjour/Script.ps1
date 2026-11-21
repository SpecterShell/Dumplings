$Object1 = $Global:DumplingsStorage.AppleProducts

# x86
$Object2 = $Object1.Products.GetEnumerator().Where({ $_.Value.Contains('ServerMetadataURL') -and $_.Value.ServerMetadataURL.Contains('WINDOWS_iTunes.smd') -and $_.Value.Packages.GetEnumerator().Where({ $_.URL.Contains('Bonjour.msi') }, 'First') }, 'Last')[-1].Value
$Object3 = Invoke-RestMethod -Uri $Object2.Distributions.English
$VersionX86 = $Object3.'installer-gui-script'.choice.'pkg-ref'.Where({ $_.id -eq 'Bonjour' }, 'First')[0].version

# x64
$Object4 = $Object1.Products.GetEnumerator().Where({ $_.Value.Contains('ServerMetadataURL') -and $_.Value.ServerMetadataURL.Contains('WINDOWS64_iTunes.smd') -and $_.Value.Packages.GetEnumerator().Where({ $_.URL.Contains('Bonjour64.msi') }, 'First') }, 'Last')[-1].Value
$Object5 = Invoke-RestMethod -Uri $Object4.Distributions.English
$VersionX64 = $Object5.'installer-gui-script'.choice.'pkg-ref'.Where({ $_.id -eq 'Bonjour64' }, 'First')[0].version

if ($VersionX86 -ne $VersionX64) {
  $this.Log("Inconsistent versions: x86: ${VersionX86}, x64: ${VersionX64}", 'Error')
  return
}

# Version
$this.CurrentState.Version = $VersionX64

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object2.Packages.GetEnumerator().Where({ $_.URL.Contains('Bonjour.msi') }, 'First')[0].URL | ConvertTo-Https
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object4.Packages.GetEnumerator().Where({ $_.URL.Contains('Bonjour64.msi') }, 'First')[0].URL | ConvertTo-Https
}

# # ReleaseTime
# $this.CurrentState.ReleaseTime = $Object4.PostDate.ToUniversalTime()

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
    $this.Submit()
  }
}
