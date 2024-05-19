$Object1 = (Invoke-RestMethod -Uri 'https://restapiext.solidworks.com/FreeDL/v1.0/FreeAPI/Downloads2/All?api_key=49a246f63bee47b7a1394da7e3ec5b4c').data.Where({ $_.ID -eq 335 }, 'First')[0]

# Installer
$this.CurrentState.Installer += $Installer = [ordered]@{
  InstallerUrl = ([uri](Get-RedirectedUrl -Uri $Object1.FILEURL)).GetLeftPart([System.UriPartial]::Path)
}

# Version
$this.CurrentState.Version = $Installer.InstallerUrl -replace '.+/(\d+)\.(\d+)\.(\d+)\.(\d+).+', '$1.$2$3.$4'

# ReleaseTime
$this.CurrentState.ReleaseTime = [datetime]::ParseExact($Object1.DATERELEASED, 'MM/dd/yyyy', $null).ToString('yyyy-MM-dd')

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
    $InstallerFileExtracted = $InstallerFile | Expand-InstallShield
    $MsiInstallerFile = Join-Path $InstallerFileExtracted 'eDrawings.msi'

    $Installer['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    $Installer['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        ProductCode   = $Installer['ProductCode'] = $MsiInstallerFile | Read-ProductCodeFromMsi
        UpgradeCode   = $MsiInstallerFile | Read-UpgradeCodeFromMsi
        InstallerType = 'msi'
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
