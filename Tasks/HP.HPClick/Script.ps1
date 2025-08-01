$Object1 = Invoke-RestMethod -Uri 'https://support.hp.com/wcc-services/swd-v2/driverDetails?authState=anonymous&template=documentTemplate' -Method Post -Body (
  @{
    productLineCode  = 'GE'
    lc               = 'en'
    cc               = 'us'
    osTMSId          = '1117042031711110499111149613201312551119131'
    osName           = 'Windows 11'
    productSeriesOid = 15550865
  } | ConvertTo-Json -Compress
) -ContentType 'application/json'

# User installer
$Object2 = $Object1.data.softwareTypes.Where({ $_.accordionName -eq 'Software' }, 'First')[0].softwareDriversList[0].latestVersionDriver
$VersionUser = $Object2.version

# Machine installer
$Object3 = $Object1.data.softwareTypes.Where({ $_.accordionName -eq 'IT Advance Installation Package' }, 'First')[0].softwareDriversList[0].latestVersionDriver
$VersionMachine = $Object3.version

if ($VersionUser -ne $VersionMachine) {
  $this.Log("Inconsistent versions: User: ${VersionUser}, Machine: ${VersionMachine}", 'Error')
  return
}

# Version
$this.CurrentState.Version = $VersionUser

# Installer
$this.CurrentState.Installer += [ordered]@{
  Scope        = 'user'
  InstallerUrl = $Object2.fileUrl
}
$this.CurrentState.Installer += $InstallerMachine = [ordered]@{
  Scope        = 'machine'
  InstallerUrl = $Object3.fileUrl
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.versionUpdatedDate.ToUniversalTime()

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object2.detailInformation.fixesAndEnhancements | ConvertFrom-Html | Get-TextContent | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$InstallerMachine.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $InstallerMachine.InstallerUrl
    $InstallerFileExtracted = $InstallerFile | Expand-InstallShield
    $InstallerFile2 = Join-Path $InstallerFileExtracted 'HP Click.msi'
    # ProductCode
    $InstallerMachine['ProductCode'] = $InstallerFile2 | Read-ProductCodeFromMsi
    # AppsAndFeaturesEntries
    $InstallerMachine['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        Publisher     = $InstallerFile2 | Read-MsiProperty -Query "SELECT Value FROM Property WHERE Property='Manufacturer'"
        UpgradeCode   = $InstallerFile2 | Read-UpgradeCodeFromMsi
        InstallerType = 'msi'
      }
    )
    Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'

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
