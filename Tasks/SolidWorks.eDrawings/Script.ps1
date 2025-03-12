$Object1 = (Invoke-RestMethod -Uri 'https://restapiext.solidworks.com/FreeDL/v1.0/FreeAPI/Downloads2/All?api_key=49a246f63bee47b7a1394da7e3ec5b4c').data.Where({ $_.ID -eq 335 }, 'First')[0]

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl -Uri $Object1.FILEURL | Split-Uri -LeftPart Path
}

# Version
$this.CurrentState.Version = $this.CurrentState.Installer[0].InstallerUrl -replace '.+/(\d+)\.(\d+)\.(\d+)\.(\d+).+', '$1.$2$3.$4'

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact($Object1.DATERELEASED, 'MM/dd/yyyy', $null).ToString('yyyy-MM-dd')
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $WinGetInstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    $InstallerFileExtracted = $InstallerFile | Expand-InstallShield
    $InstallerFile2 = Join-Path $InstallerFileExtracted 'eDrawings.msi'
    # AppsAndFeaturesEntries + ProductCode
    $this.CurrentState.Installer[0]['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        ProductCode   = $this.CurrentState.Installer[0]['ProductCode'] = $InstallerFile2 | Read-ProductCodeFromMsi
        UpgradeCode   = $InstallerFile2 | Read-UpgradeCodeFromMsi
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
