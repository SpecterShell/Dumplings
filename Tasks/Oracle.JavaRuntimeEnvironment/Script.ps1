$Object1 = Invoke-RestMethod -Uri 'https://www.java.com/content/published/api/v1.1/items?q=(id eq "CORE7B1FF38771234E749E94A8C83F78F516" or id eq "COREFA37E773006D4BE183DB8D7F504C5718")&channelToken=1f7d2611846d4457b213dfc9048724dc' -Headers @{ Accept = '*/*'; Connection = 'close' }
$Object2 = $Object1.items.Where({ $_.id -eq 'CORE7B1FF38771234E749E94A8C83F78F516' }, 'First')[0]
$Object3 = $Object1.items.Where({ $_.id -eq 'COREFA37E773006D4BE183DB8D7F504C5718' }, 'First')[0]

# Version
$this.CurrentState.Version = $Object3.fields.json.latest8Version

# Installer
$this.CurrentState.Installer += $InstallerX86 = [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object2.fields.json.bundleUrl + $Object3.fields.json.win_offline_bundle + '_' + $Object3.fields.json.secID
}
$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object2.fields.json.bundleUrl + $Object3.fields.json.win_x64_bundle + '_' + $Object3.fields.json.secID
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object3.updatedDate.value.ToUniversalTime()
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $InstallerFile = Get-TempFile -Uri $InstallerX86.InstallerUrl
    $InstallerFileExtracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y '-t#' -o"${InstallerFileExtracted}" $InstallerFile '2.wrapper_jre_offline.exe' | Out-Host
    $InstallerFile2 = Join-Path $InstallerFileExtracted '2.wrapper_jre_offline.exe'
    $InstallerFile2Extracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y '-t#' -o"${InstallerFile2Extracted}" $InstallerFile2 '2.msi' | Out-Host
    $InstallerFile3 = Join-Path $InstallerFile2Extracted '2.msi'
    # InstallerSha256
    $InstallerX86['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile3 | Read-ProductVersionFromMsi
    # AppsAndFeaturesEntries + ProductCode
    $InstallerX86['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        DisplayName   = "Java 8 Update $($Object3.fields.json.l8VersNumber)"
        ProductCode   = $InstallerX86['ProductCode'] = $InstallerFile3 | Read-ProductCodeFromMsi
        UpgradeCode   = $InstallerFile3 | Read-UpgradeCodeFromMsi
        InstallerType = 'wix'
      }
    )

    $InstallerFile = Get-TempFile -Uri $InstallerX64.InstallerUrl
    $InstallerFileExtracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y '-t#' -o"${InstallerFileExtracted}" $InstallerFile '2.wrapper_jre_offline.exe' | Out-Host
    $InstallerFile2 = Join-Path $InstallerFileExtracted '2.wrapper_jre_offline.exe'
    $InstallerFile2Extracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y '-t#' -o"${InstallerFile2Extracted}" $InstallerFile2 '2.msi' | Out-Host
    $InstallerFile3 = Join-Path $InstallerFile2Extracted '2.msi'
    # InstallerSha256
    $InstallerX64['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile3 | Read-ProductVersionFromMsi
    # AppsAndFeaturesEntries + ProductCode
    $InstallerX64['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        DisplayName   = "Java 8 Update $($Object3.fields.json.l8VersNumber) (64-bit)"
        ProductCode   = $InstallerX64['ProductCode'] = $InstallerFile3 | Read-ProductCodeFromMsi
        UpgradeCode   = $InstallerFile3 | Read-UpgradeCodeFromMsi
        InstallerType = 'wix'
      }
    )

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
