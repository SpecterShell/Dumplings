# Installer
$this.CurrentState.Installer += $InstallerX86 = [ordered]@{
  Architecture = 'x86'
  InstallerUrl = Get-RedirectedUrl -Uri 'https://www.apple.com/itunes/download/win32'
}
if ($this.LastState.Installer.Count -gt 0 -and $this.LastState.Installer.Where({ $_.Architecture -eq 'x86' }, 'First')[0].InstallerUrl -eq $InstallerX86.InstallerUrl) {
  $this.Log("The x86 installer for the version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Get-RedirectedUrl -Uri 'https://www.apple.com/itunes/download/win64'
}
if ($this.LastState.Installer.Count -gt 0 -and $this.LastState.Installer.Where({ $_.Architecture -eq 'x64' }, 'First')[0].InstallerUrl -eq $InstallerX64.InstallerUrl) {
  $this.Log("The x64 installer for the version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

$this.InstallerFiles[$InstallerX86.InstallerUrl] = $InstallerX86File = Get-TempFile -Uri $InstallerX86.InstallerUrl
$InstallerX86FileExtracted = New-TempFolder
7z.exe e -aoa -ba -bd -y -o"${InstallerX86FileExtracted}" $InstallerX86File 'iTunes.msi' | Out-Host
$InstallerX86File2 = Join-Path $InstallerX86FileExtracted 'iTunes.msi'
# AppsAndFeaturesEntries + ProductCode
$InstallerX86['AppsAndFeaturesEntries'] = @(
  [ordered]@{
    ProductCode   = $InstallerX86['ProductCode'] = $InstallerX86File2 | Read-ProductCodeFromMsi
    UpgradeCode   = $InstallerX86File2 | Read-UpgradeCodeFromMsi
    InstallerType = 'wix'
  }
)
$VersionX86 = $InstallerX86File2 | Read-ProductVersionFromMsi
Remove-Item -Path $InstallerX86FileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'

$this.InstallerFiles[$InstallerX64.InstallerUrl] = $InstallerX64File = Get-TempFile -Uri $InstallerX64.InstallerUrl
$InstallerX64FileExtracted = New-TempFolder
7z.exe e -aoa -ba -bd -y -o"${InstallerX64FileExtracted}" $InstallerX64File 'iTunes64.msi' | Out-Host
$InstallerX64File2 = Join-Path $InstallerX64FileExtracted 'iTunes64.msi'
# AppsAndFeaturesEntries + ProductCode
$InstallerX64['AppsAndFeaturesEntries'] = @(
  [ordered]@{
    ProductCode   = $InstallerX64['ProductCode'] = $InstallerX64File2 | Read-ProductCodeFromMsi
    UpgradeCode   = $InstallerX64File2 | Read-UpgradeCodeFromMsi
    InstallerType = 'wix'
  }
)
$VersionX64 = $InstallerX64File2 | Read-ProductVersionFromMsi
Remove-Item -Path $InstallerX64FileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'

if ($VersionX86 -ne $VersionX64) {
  $this.Log("Inconsistent versions: x86: ${VersionX86}, x64: ${VersionX64}", 'Error')
  return
}

# Version
$this.CurrentState.Version = $VersionX64

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object1 = $Global:DumplingsStorage.AppleProducts.Products.GetEnumerator().Where({ $_.Value.Contains('ServerMetadataURL') -and $_.Value.ServerMetadataURL.Contains('WINDOWS64_iTunes.smd') })[-1].Value
      $Object2 = Invoke-RestMethod -Uri $Object1.Distributions.English

      if ($Object2.'installer-gui-script'.choice.'pkg-ref'.Where({ $_.id -eq 'iTunes64' }, 'First')[0].version) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $Object1.PostDate.ToUniversalTime()

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = [regex]::Match($Object2.'installer-gui-script'.localization.strings.'#cdata-section', "(?s)`"SU_DESCRIPTION`"\s*=\s*'(.+)'").Groups[1].Value | ConvertFrom-Html | Get-TextContent | Format-Text
        }

        # $Object3 = Invoke-RestMethod -Uri $Object1.Distributions.zh_CN

        # # ReleaseNotes (zh-CN)
        # $this.CurrentState.Locale += [ordered]@{
        #   Locale = 'zh-CN'
        #   Key    = 'ReleaseNotes'
        #   Value  = [regex]::Match($Object3.'installer-gui-script'.localization.strings.'#cdata-section', "(?s)`"SU_DESCRIPTION`"\s*=\s*'(.+)'").Groups[1].Value | ConvertFrom-Html | Get-TextContent | Format-Text
        # }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
    $this.Submit()
  }
}
