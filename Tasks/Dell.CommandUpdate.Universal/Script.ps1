$Path = Get-TempFile -Uri 'https://dellupdater.dell.com/non_du/ClientService/Catalog/Platform/PrecedenceCatalog.cab'
expand.exe -R $Path
$Object1 = (Join-Path $Path '..' 'PrecedenceCatalog.xml' | Get-Item | Get-Content -Raw | ConvertFrom-Xml).Precedence.Demoted.SoftwareComponent.Where({ $_.Name.Display.'#cdata-section' -eq 'Dell Command | Update Windows Universal Application' }, 'First')[0]

# Version
$this.CurrentState.Version = $Object1.vendorVersion

# Installer
$this.CurrentState.Installer += $Installer = [ordered]@{
  InstallerUrl = 'https://dl.dell.com/' + $Object1.path
}

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

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl -UserAgent 'Microsoft-Delivery-Optimization/10.0'
    $InstallerFileExtracted = New-TempFolder
    7z e -aoa -ba -bd -o"${InstallerFileExtracted}" $InstallerFile

    $Object2 = Join-Path $InstallerFileExtracted 'Mup.xml' | Get-Item | Get-Content -Raw | ConvertFrom-Xml
    $NestedInstallerFile = Join-Path $InstallerFileExtracted $Object2.MUPDefinition.executable.executablename
    $NestedInstallerFileExtracted = $NestedInstallerFile | Expand-InstallShield

    $MsiInstallerFile = Join-Path $NestedInstallerFileExtracted 'DellCommandUpdateApp.msi'

    $Installer['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    $Installer['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        ProductCode   = $Installer['ProductCode'] = $MsiInstallerFile | Read-ProductCodeFromMsi
        UpgradeCode   = $MsiInstallerFile | Read-UpgradeCodeFromMsi
        InstallerType = 'msi'
      }
    )

    try {
      $Object3 = Join-Path $InstallerFileExtracted 'package.xml' | Get-Item | Get-Content -Raw -Encoding unicode | ConvertFrom-Xml

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object3.SoftwareComponent.RevisionHistory.Display.'#cdata-section' | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Write()
  }
  'Changed|Updated' {
    $this.Print()
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
