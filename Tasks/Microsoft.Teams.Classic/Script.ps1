# x86
$Object1 = Invoke-RestMethod -Uri 'https://teams.live.com/downloads/getinstaller?arch=x86'
$VersionX86 = [regex]::Match($Object1.installerUrl, '(\d+\.\d+\.\d+\.\d+)').Groups[1].Value

# x64
$Object2 = Invoke-RestMethod -Uri 'https://teams.live.com/downloads/getinstaller?arch=x64'
$VersionX64 = [regex]::Match($Object2.installerUrl, '(\d+\.\d+\.\d+\.\d+)').Groups[1].Value

# arm64
$Object3 = Invoke-RestMethod -Uri 'https://teams.live.com/downloads/getinstaller?arch=arm64'
$VersionArm64 = [regex]::Match($Object3.installerUrl, '(\d+\.\d+\.\d+\.\d+)').Groups[1].Value

$Identical = $true
if (@(@($VersionX86, $VersionX64, $VersionArm64) | Sort-Object -Unique).Count -gt 1) {
  $this.Log('Distinct versions detected', 'Warning')
  $Identical = $false
}

# Version
$this.CurrentState.Version = $VersionX64

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'exe'
  InstallerUrl  = $Object1.installerUrl
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'exe'
  InstallerUrl  = $Object2.installerUrl
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'exe'
  InstallerUrl  = $Object3.installerUrl
}
$this.CurrentState.Installer += $InstallerWixX86 = [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'wix'
  InstallerUrl  = $Object1.installerUrl -replace '\.exe$', '.msi'
}
$this.CurrentState.Installer += $InstallerWixX64 = [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = $Object2.installerUrl -replace '\.exe$', '.msi'
}
$this.CurrentState.Installer += $InstallerWixARM64 = [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'wix'
  InstallerUrl  = $Object3.installerUrl -replace '\.exe$', '.msi'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $InstallerFileX86 = Get-TempFile -Uri $InstallerWixX86.InstallerUrl
    $InstallerWixX86['InstallerSha256'] = (Get-FileHash -Path $InstallerFileX86 -Algorithm SHA256).Hash
    $InstallerWixX86['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        DisplayName    = 'Teams Machine-Wide Installer'
        DisplayVersion = $InstallerFileX86 | Read-ProductVersionFromMsi
        ProductCode    = $InstallerWixX86['ProductCode'] = $InstallerFileX86 | Read-ProductCodeFromMsi
        UpgradeCode    = $InstallerFileX86 | Read-UpgradeCodeFromMsi
      }
    )

    $InstallerFileX64 = Get-TempFile -Uri $InstallerWixX64.InstallerUrl
    $InstallerWixX64['InstallerSha256'] = (Get-FileHash -Path $InstallerFileX64 -Algorithm SHA256).Hash
    $InstallerWixX64['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        DisplayName    = 'Teams Machine-Wide Installer'
        DisplayVersion = $InstallerFileX64 | Read-ProductVersionFromMsi
        ProductCode    = $InstallerWixX64['ProductCode'] = $InstallerFileX64 | Read-ProductCodeFromMsi
        UpgradeCode    = $InstallerFileX64 | Read-UpgradeCodeFromMsi
      }
    )

    $InstallerFileArm64 = Get-TempFile -Uri $InstallerWixARM64.InstallerUrl
    $InstallerWixARM64['InstallerSha256'] = (Get-FileHash -Path $InstallerFileArm64 -Algorithm SHA256).Hash
    $InstallerWixARM64['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        DisplayName    = 'Teams Machine-Wide Installer'
        DisplayVersion = $InstallerFileArm64 | Read-ProductVersionFromMsi
        ProductCode    = $InstallerWixARM64['ProductCode'] = $InstallerFileArm64 | Read-ProductCodeFromMsi
        UpgradeCode    = $InstallerFileArm64 | Read-UpgradeCodeFromMsi
      }
    )

    $this.Write()
  }
  'Changed|Updated' {
    $this.Print()
    $this.Message()
  }
  ({ $_ -match 'Updated' -and $Identical }) {
    $this.Submit()
  }
}
