$Prefix = 'https://app.ringcentral.com/download/'

$Object1 = Invoke-WebRequest -Uri "${Prefix}latest.yml?noCache=$(Get-Random)" | Read-ResponseContent | ConvertFrom-Yaml
$Object2 = Invoke-WebRequest -Uri "${Prefix}latest-arm64.yml?noCache=$(Get-Random)" | Read-ResponseContent | ConvertFrom-Yaml

$Identical = $true
if ($Object1.version -ne $Object2.version) {
  $this.Log('Distinct versions detected', 'Warning')
  $Identical = $false
}

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture           = 'x64'
  InstallerType          = 'nullsoft'
  InstallerUrl           = $Prefix + $Object1.files[0].url
  AppsAndFeaturesEntries = @(
    [ordered]@{
      DisplayVersion = $Object1.version
      ProductCode    = '584acf4c-ebc3-56fa-9cfd-586227f098ba'
    }
  )
}
$this.CurrentState.Installer += $InstallerWixX64 = [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = $Prefix + $Object1.files[0].url.Replace('.exe', '-x64.msi')
}
$this.CurrentState.Installer += [ordered]@{
  Architecture           = 'arm64'
  InstallerType          = 'nullsoft'
  InstallerUrl           = $Prefix + $Object2.files[0].url
  AppsAndFeaturesEntries = @(
    [ordered]@{
      DisplayVersion = $Object2.version
      ProductCode    = '584acf4c-ebc3-56fa-9cfd-586227f098ba'
    }
  )
}
$this.CurrentState.Installer += $InstallerWixARM64 = [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'wix'
  InstallerUrl  = $Prefix + $Object2.files[0].url.Replace('.exe', '.msi')
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.releaseDate | Get-Date -AsUTC

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    # RealVersion + AppsAndFeaturesEntries
    $InstallerFileX64 = Get-TempFile -Uri $InstallerWixX64.InstallerUrl
    $InstallerWixX64['InstallerSha256'] = (Get-FileHash -Path $InstallerFileX64 -Algorithm SHA256).Hash
    $InstallerWixX64['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        DisplayVersion = $this.CurrentState.RealVersion = $InstallerFileX64 | Read-ProductVersionFromMsi
        ProductCode    = $InstallerWixX64['ProductCode'] = $InstallerFileX64 | Read-ProductCodeFromMsi
        UpgradeCode    = $InstallerFileX64 | Read-UpgradeCodeFromMsi
      }
    )

    $InstallerFileArm64 = Get-TempFile -Uri $InstallerWixARM64.InstallerUrl
    $InstallerWixARM64['InstallerSha256'] = (Get-FileHash -Path $InstallerFileArm64 -Algorithm SHA256).Hash
    $InstallerWixARM64['AppsAndFeaturesEntries'] = @(
      [ordered]@{
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
