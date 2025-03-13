# x64
$Object1 = $Global:DumplingsStorage.DellCatalog | Select-Xml -XPath '/dm:Manifest/dm:SoftwareComponent[./dm:SupportedDevices/dm:Device/@componentID="23400"]' -Namespace @{ dm = $Global:DumplingsStorage.DellCatalog.Manifest.xmlns } | Select-Object -ExpandProperty 'Node' -Last 1
# arm64
# $Object2 = $Global:DumplingsStorage.DellCatalog2 | Select-Xml -XPath '/dm:Manifest/dm:SoftwareComponent[./dm:SupportedDevices/dm:Device/@componentID="113763"]' -Namespace @{ dm = $Global:DumplingsStorage.DellCatalog2.Manifest.xmlns } | Select-Object -ExpandProperty 'Node' -Last 1

# if ($Object1.vendorVersion -ne $Object2.vendorVersion) {
#   $this.Log("x64 version: $($Object1.vendorVersion)")
#   $this.Log("arm64 version: $($Object2.vendorVersion)")
#   throw 'Inconsistent versions detected'
# }

# Version
$this.CurrentState.Version = $Object1.vendorVersion

# Installer
$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Join-Uri 'https://dl.dell.com/' $Object1.path
}
# $this.CurrentState.Installer += $InstallerARM64 = [ordered]@{
#   Architecture = 'arm64'
#   InstallerUrl = Join-Uri 'https://dl.dell.com/' $Object2.path
# }

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.dateTime | Get-Date -AsUTC

      # PackageName
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'PackageUrl'
        Value = "https://www.dell.com/support/home/drivers/DriversDetails?driverId=$($Object1.releaseID)"
      }
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'PackageUrl'
        Value  = "https://www.dell.com/support/home/zh-cn/drivers/DriversDetails?driverId=$($Object1.releaseID)"
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$InstallerX64.InstallerUrl] = $InstallerX64File = Get-TempFile -Uri $InstallerX64.InstallerUrl -UserAgent $WinGetUserAgent
    $InstallerX64FileExtracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y -o"${InstallerX64FileExtracted}" $InstallerX64File | Out-Host
    $Object3 = Join-Path $InstallerX64FileExtracted 'Mup.xml' | Get-Item | Get-Content -Raw | ConvertFrom-Xml
    $InstallerX64File2 = Join-Path $InstallerX64FileExtracted $Object3.MUPDefinition.executable.executablename
    $InstallerX64File2Extracted = $InstallerX64File2 | Expand-InstallShield
    $InstallerX64File3 = Join-Path $InstallerX64File2Extracted 'DellCommandUpdate.msi'
    # AppsAndFeaturesEntries + ProductCode
    $InstallerX64['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        ProductCode   = $InstallerX64['ProductCode'] = $InstallerX64File3 | Read-ProductCodeFromMsi
        UpgradeCode   = $InstallerX64File3 | Read-UpgradeCodeFromMsi
        InstallerType = 'msi'
      }
    )

    # $this.InstallerFiles[$InstallerARM64.InstallerUrl] = $InstallerARM64File = Get-TempFile -Uri $InstallerARM64.InstallerUrl -UserAgent $WinGetUserAgent
    # $InstallerARM64FileExtracted = New-TempFolder
    # 7z.exe e -aoa -ba -bd -y -o"${InstallerARM64FileExtracted}" $InstallerARM64File | Out-Host
    # $Object4 = Join-Path $InstallerARM64FileExtracted 'Mup.xml' | Get-Item | Get-Content -Raw | ConvertFrom-Xml
    # $InstallerARM64File2 = Join-Path $InstallerARM64FileExtracted $Object4.MUPDefinition.executable.executablename
    # $InstallerARM64File2Extracted = $InstallerARM64File2 | Expand-InstallShield
    # $InstallerARM64File3 = Join-Path $InstallerARM64File2Extracted 'DellCommandUpdate.msi'
    # # AppsAndFeaturesEntries + ProductCode
    # $InstallerARM64['AppsAndFeaturesEntries'] = @(
    #   [ordered]@{
    #     ProductCode   = $InstallerARM64['ProductCode'] = $InstallerARM64File3 | Read-ProductCodeFromMsi
    #     UpgradeCode   = $InstallerARM64File3 | Read-UpgradeCodeFromMsi
    #     InstallerType = 'msi'
    #   }
    # )

    try {
      $Object4 = Join-Path $InstallerX64FileExtracted 'package.xml' | Get-Item | Get-Content -Raw -Encoding unicode | ConvertFrom-Xml

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object4.SoftwareComponent.RevisionHistory.Display.'#cdata-section' | Format-Text
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
  'Updated' {
    $this.Submit()
  }
}
