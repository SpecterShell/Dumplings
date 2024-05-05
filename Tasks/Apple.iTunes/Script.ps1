$Object1 = Invoke-RestMethod -Uri 'https://swcatalog.apple.com/content/catalogs/others/index-windows-1.sucatalog' | ConvertFrom-PropertyList

# x86
$Object2 = $Object1.Products.GetEnumerator().Where({ $_.Value.Contains('ServerMetadataURL') -and $_.Value.ServerMetadataURL.Contains('WINDOWS_iTunes.smd') })[-1].Value
$Object3 = Invoke-RestMethod -Uri $Object2.Distributions.English
# $Object4 = Invoke-RestMethod -Uri $Object2.Distributions.zh_CN
$VersionX86 = $Object3.'installer-gui-script'.choice.'pkg-ref'.Where({ $_.id -eq 'iTunes' }, 'First')[0].version

# x64
$Object5 = $Object1.Products.GetEnumerator().Where({ $_.Value.Contains('ServerMetadataURL') -and $_.Value.ServerMetadataURL.Contains('WINDOWS64_iTunes.smd') })[-1].Value
$Object6 = Invoke-RestMethod -Uri $Object5.Distributions.English
$Object7 = Invoke-RestMethod -Uri $Object5.Distributions.zh_CN
$VersionX64 = $Object6.'installer-gui-script'.choice.'pkg-ref'.Where({ $_.id -eq 'iTunes64' }, 'First')[0].version

$Identical = $true
if ($VersionX86 -ne $VersionX64) {
  $this.Log('Distinct versions detected', 'Warning')
  $Identical = $false
}

# Version
$this.CurrentState.Version = $VersionX64

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object2.Packages.GetEnumerator().Where({ $_.URL.Contains('iTunes.msi') }, 'First')[0].URL | ConvertTo-Https
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object5.Packages.GetEnumerator().Where({ $_.URL.Contains('iTunes64.msi') }, 'First')[0].URL | ConvertTo-Https
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object5.PostDate.ToUniversalTime()

# ReleaseNotes (en-US)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotes'
  Value  = [regex]::Match($Object6.'installer-gui-script'.localization.strings.'#cdata-section', "(?s)`"SU_DESCRIPTION`"\s*=\s*'(.+)'").Groups[1].Value | ConvertFrom-Html | Get-TextContent | Format-Text
}

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = [regex]::Match($Object7.'installer-gui-script'.localization.strings.'#cdata-section', "(?s)`"SU_DESCRIPTION`"\s*=\s*'(.+)'").Groups[1].Value | ConvertFrom-Html | Get-TextContent | Format-Text
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  ({ $_ -match 'Updated' -and $Identical }) {
    $this.Submit()
  }
}
