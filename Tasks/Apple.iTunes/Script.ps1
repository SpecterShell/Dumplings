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

# InstallerSha256 + ProductCode + AppsAndFeaturesEntries
$InstallerX86File = Get-TempFile -Uri $InstallerX86.InstallerUrl
$InstallerX86FileExtracted = New-TempFolder
7z.exe e -aoa -ba -bd -y -o"${InstallerX86FileExtracted}" $InstallerX86File 'iTunes.msi' | Out-Host
$InstallerX86MsiFile = Join-Path $InstallerX86FileExtracted 'iTunes.msi'
$InstallerX86['InstallerSha256'] = (Get-FileHash -Path $InstallerX86File -Algorithm SHA256).Hash
$InstallerX86['AppsAndFeaturesEntries'] = @(
  [ordered]@{
    ProductCode   = $InstallerX86['ProductCode'] = $InstallerX86MsiFile | Read-ProductCodeFromMsi
    UpgradeCode   = $InstallerX86MsiFile | Read-UpgradeCodeFromMsi
    InstallerType = 'wix'
  }
)
$VersionX86 = $InstallerX86MsiFile | Read-ProductVersionFromMsi
$this.Log("x86 version: ${VersionX86}")

$InstallerX64File = Get-TempFile -Uri $InstallerX64.InstallerUrl
$InstallerX64FileExtracted = New-TempFolder
7z.exe e -aoa -ba -bd -y -o"${InstallerX64FileExtracted}" $InstallerX64File 'iTunes64.msi' | Out-Host
$InstallerX64MsiFile = Join-Path $InstallerX64FileExtracted 'iTunes64.msi'
$InstallerX64['InstallerSha256'] = (Get-FileHash -Path $InstallerX64File -Algorithm SHA256).Hash
$InstallerX64['AppsAndFeaturesEntries'] = @(
  [ordered]@{
    ProductCode   = $InstallerX64['ProductCode'] = $InstallerX64MsiFile | Read-ProductCodeFromMsi
    UpgradeCode   = $InstallerX64MsiFile | Read-UpgradeCodeFromMsi
    InstallerType = 'wix'
  }
)
$VersionX64 = $InstallerX64MsiFile | Read-ProductVersionFromMsi
$this.Log("x64 version: ${VersionX64}")

if ($VersionX86 -ne $VersionX64) {
  $this.Log("x86 version: ${VersionX86}")
  $this.Log("x64 version: ${VersionX64}")
  throw 'Inconsistent versions detected'
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
