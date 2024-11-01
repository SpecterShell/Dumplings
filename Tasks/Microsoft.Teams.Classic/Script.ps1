$Object1 = (Invoke-RestMethod -Uri 'https://config.teams.microsoft.com/config/v1/MicrosoftTeams/27_1.0.0.0?environment=prod&agents=TeamsBuilds').TeamsBuilds.BuildSettings.Desktop

$Identical = $true
if (@(@('windows', 'windows64', 'arm64') | Sort-Object -Property { $Object1.$_.latestVersion } -Unique).Count -gt 1) {
  $this.Log('Inconsistent versions detected', 'Warning')
  $this.Log("Windows x86 version: $($Object1.windows.latestVersion)")
  $this.Log("Windows x64 version: $($Object1.windows64.latestVersion)")
  $this.Log("Windows arm64 version: $($Object1.arm64.latestVersion)")
  $Identical = $false
}

# Version
$this.CurrentState.Version = $Object1.windows64.latestVersion

# Installer
$Prefix = 'https://statics.teams.cdn.office.net'
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'exe'
  InstallerUrl  = "${Prefix}/production-windows/$($Object1.windows.latestVersion)/Teams_windows.exe"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'exe'
  InstallerUrl  = "${Prefix}/production-windows-x64/$($Object1.windows64.latestVersion)/Teams_windows_x64.exe"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'exe'
  InstallerUrl  = "${Prefix}/production-windows-arm64/$($Object1.arm64.latestVersion)/Teams_windows_arm64.exe"
}
$this.CurrentState.Installer += $InstallerWixX86 = [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'wix'
  InstallerUrl  = "${Prefix}/production-windows/$($Object1.windows.latestVersion)/Teams_windows.msi"
}
$this.CurrentState.Installer += $InstallerWixX64 = [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = "${Prefix}/production-windows-x64/$($Object1.windows64.latestVersion)/Teams_windows_x64.msi"
}
$this.CurrentState.Installer += $InstallerWixARM64 = [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'wix'
  InstallerUrl  = "${Prefix}/production-windows-arm64/$($Object1.arm64.latestVersion)/Teams_windows_arm64.msi"
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
