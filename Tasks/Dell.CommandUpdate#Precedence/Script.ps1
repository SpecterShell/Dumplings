$Object1 = $Global:DumplingsStorage.DellPrecedenceCatalog | Select-Xml -XPath '/dm:Precedence/dm:Demoted/dm:SoftwareComponent[./dm:SupportedDevices/dm:Device/@componentID="23400"]' -Namespace @{ dm = $Global:DumplingsStorage.DellPrecedenceCatalog.Precedence.xmlns } | Select-Object -ExpandProperty 'Node' -Last 1

# Version
$this.CurrentState.Version = $Object1.vendorVersion

# Installer
$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  InstallerUrl = 'https://dl.dell.com/' + $Object1.path
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.dateTime | Get-Date -AsUTC

      # # PackageName
      # $this.CurrentState.Locale += [ordered]@{
      #   Key   = 'PackageUrl'
      #   Value = "https://www.dell.com/support/home/drivers/DriversDetails?driverId=$($Object1.releaseID)"
      # }
      # $this.CurrentState.Locale += [ordered]@{
      #   Locale = 'zh-CN'
      #   Key    = 'PackageUrl'
      #   Value  = "https://www.dell.com/support/home/zh-cn/drivers/DriversDetails?driverId=$($Object1.releaseID)"
      # }
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

    Remove-Item -Path $InstallerX64File2Extracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
    Remove-Item -Path $InstallerX64FileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'

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
