$Object1 = Invoke-WebRequest -Uri 'https://www.realvnc.com/en/connect/download/viewer/' | ConvertFrom-Html

$InstallerUrl = $Object1.SelectSingleNode('//option[contains(@data-file, "-msi.zip")]').Attributes['data-file'].Value

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '(\d+(?:\.\d+){2,})').Groups[1].Value

# Installer
$this.CurrentState.Installer += $InstallerX86 = [ordered]@{
  Architecture         = 'x86'
  InstallerUrl         = $InstallerUrl
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = "VNC-Viewer-$($this.CurrentState.Version)-Windows-en-32bit.msi"
    }
  )
}
$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture         = 'x64'
  InstallerUrl         = $InstallerUrl
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = "VNC-Viewer-$($this.CurrentState.Version)-Windows-en-64bit.msi"
    }
  )
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    $NestedInstallerFileRoot = New-TempFolder

    7z.exe e -aoa -ba -bd -y -o"${NestedInstallerFileRoot}" $InstallerFile $InstallerX86.NestedInstallerFiles[0].RelativeFilePath | Out-Host
    $NestedInstallerFileX86 = Join-Path $NestedInstallerFileRoot $InstallerX86.NestedInstallerFiles[0].RelativeFilePath
    # RealVersion
    $this.CurrentState.RealVersion = $NestedInstallerFileX86 | Read-ProductVersionFromMsi
    # InstallerSha256
    $InstallerX86['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # AppsAndFeaturesEntries
    $InstallerX86['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        ProductCode = $InstallerX86['ProductCode'] = $NestedInstallerFileX86 | Read-ProductCodeFromMsi
        UpgradeCode = $NestedInstallerFileX86 | Read-UpgradeCodeFromMsi
      }
    )

    7z.exe e -aoa -ba -bd -y -o"${NestedInstallerFileRoot}" $InstallerFile $InstallerX64.NestedInstallerFiles[0].RelativeFilePath | Out-Host
    $NestedInstallerFileX64 = Join-Path $NestedInstallerFileRoot $InstallerX64.NestedInstallerFiles[0].RelativeFilePath
    # RealVersion
    $this.CurrentState.RealVersion = $NestedInstallerFileX64 | Read-ProductVersionFromMsi
    # InstallerSha256
    $InstallerX64['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # AppsAndFeaturesEntries
    $InstallerX64['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        ProductCode = $InstallerX64['ProductCode'] = $NestedInstallerFileX64 | Read-ProductCodeFromMsi
        UpgradeCode = $NestedInstallerFileX64 | Read-UpgradeCodeFromMsi
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
