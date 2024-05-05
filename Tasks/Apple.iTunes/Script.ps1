$Object1 = $Global:DumplingsStorage.AppleProducts

# x86
$Object2 = $Object1.Products.GetEnumerator().Where({ $_.Value.Contains('ServerMetadataURL') -and $_.Value.ServerMetadataURL.Contains('WINDOWS_iTunes.smd') })[-1].Value
$Object3 = Invoke-RestMethod -Uri $Object2.Distributions.English
$VersionX86 = $Object3.'installer-gui-script'.choice.'pkg-ref'.Where({ $_.id -eq 'iTunes' }, 'First')[0].version

# x64
$Object4 = $Object1.Products.GetEnumerator().Where({ $_.Value.Contains('ServerMetadataURL') -and $_.Value.ServerMetadataURL.Contains('WINDOWS64_iTunes.smd') })[-1].Value
$Object5 = Invoke-RestMethod -Uri $Object4.Distributions.English
$VersionX64 = $Object5.'installer-gui-script'.choice.'pkg-ref'.Where({ $_.id -eq 'iTunes64' }, 'First')[0].version

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
  InstallerUrl = $Object4.Packages.GetEnumerator().Where({ $_.URL.Contains('iTunes64.msi') }, 'First')[0].URL | ConvertTo-Https
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object4.PostDate.ToUniversalTime()

# ReleaseNotes (en-US)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotes'
  Value  = [regex]::Match($Object5.'installer-gui-script'.localization.strings.'#cdata-section', "(?s)`"SU_DESCRIPTION`"\s*=\s*'(.+)'").Groups[1].Value | ConvertFrom-Html | Get-TextContent | Format-Text
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object6 = Invoke-RestMethod -Uri $Object4.Distributions.zh_CN

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = [regex]::Match($Object6.'installer-gui-script'.localization.strings.'#cdata-section', "(?s)`"SU_DESCRIPTION`"\s*=\s*'(.+)'").Groups[1].Value | ConvertFrom-Html | Get-TextContent | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }
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
