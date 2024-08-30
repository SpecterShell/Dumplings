$Object1 = Invoke-RestMethod -Uri "https://my.adobeconnect.com/common/UpdateDescr.xml?noCache=$(Get-Random)"

if ($Object1.UpdateDescr.Windows.Release[0].Version -ne $Object1.UpdateDescr.Win32.Release[0].Version) {
  $this.Log("x86 version: $($Object1.UpdateDescr.Win32.Release[0].Version)")
  $this.Log("x64 version: $($Object1.UpdateDescr.Windows.Release[0].Version)")
  throw 'Distinct versions detected'
}

# Version
$this.CurrentState.Version = $Object1.UpdateDescr.Windows.Release[0].Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture           = 'x86'
  InstallerType          = 'exe'
  InstallerUrl           = Get-RedirectedUrl1st -Uri 'https://www.adobe.com/go/Connect11_32AppStandalone'
  AppsAndFeaturesEntries = @(
    [ordered]@{
      DisplayVersion = "$($this.CurrentState.Version).32"
    }
  )
}
$this.CurrentState.Installer += [ordered]@{
  Architecture           = 'x64'
  InstallerType          = 'exe'
  InstallerUrl           = Get-RedirectedUrl1st -Uri 'https://www.adobe.com/go/Connect11AppStandalone'
  AppsAndFeaturesEntries = @(
    [ordered]@{
      DisplayVersion = "$($this.CurrentState.Version).64"
    }
  )
}
$this.CurrentState.Installer += $InstallerMsiX86 = [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'msi'
  InstallerUrl  = Get-RedirectedUrl1st -Uri 'https://www.adobe.com/go/Connect11_32msi'
}
$this.CurrentState.Installer += $InstallerMsiX64 = [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'msi'
  InstallerUrl  = Get-RedirectedUrl1st -Uri 'https://www.adobe.com/go/Connect11msi'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.UpdateDescr.Windows.Release[0].ReleaseDate | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $InstallerFileMsiX86 = Get-TempFile -Uri $InstallerMsiX86.InstallerUrl
    $InstallerMsiX86['InstallerSha256'] = (Get-FileHash -Path $InstallerFileMsiX86 -Algorithm SHA256).Hash
    $InstallerMsiX86['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        DisplayName    = 'Adobe Connect application MSI'
        Publisher      = 'Adobe '
        DisplayVersion = $InstallerFileMsiX86 | Read-ProductVersionFromMsi
        ProductCode    = $InstallerMsiX86['ProductCode'] = $InstallerFileMsiX86 | Read-ProductCodeFromMsi
        UpgradeCode    = $InstallerFileMsiX86 | Read-UpgradeCodeFromMsi
      }
    )

    $InstallerFileMsiX64 = Get-TempFile -Uri $InstallerMsiX64.InstallerUrl
    $InstallerMsiX64['InstallerSha256'] = (Get-FileHash -Path $InstallerFileMsiX64 -Algorithm SHA256).Hash
    $InstallerMsiX64['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        DisplayName    = 'Adobe Connect application MSI'
        Publisher      = 'Adobe '
        DisplayVersion = $InstallerFileMsiX64 | Read-ProductVersionFromMsi
        ProductCode    = $InstallerMsiX64['ProductCode'] = $InstallerFileMsiX64 | Read-ProductCodeFromMsi
        UpgradeCode    = $InstallerFileMsiX64 | Read-UpgradeCodeFromMsi
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
