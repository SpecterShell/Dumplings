# $Object1 = Invoke-WebRequest -Uri 'https://cdn.xsplit.com/updater/login/update.aiu' | Read-ResponseContent -Encoding 'windows-1252' | ConvertFrom-Ini
$Object1 = Invoke-WebRequest -Uri 'https://cdn.xsplit.com/updater/manual/update.aiu' | Read-ResponseContent -Encoding 'windows-1252' | ConvertFrom-Ini

# Version
$this.CurrentState.Version = $Object1.Update.ProductVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.Update.URL
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl | Rename-Item -NewName { "${_}.exe" } -PassThru | Select-Object -ExpandProperty 'FullName'
    $InstallerFileExtracted = New-TempFolder
    Start-Process -FilePath $InstallerFile -ArgumentList @('/extract', $InstallerFileExtracted) -Wait
    $InstallerFile2 = Get-ChildItem -Path $InstallerFileExtracted -Include '*.msi' -Recurse | Select-Object -First 1
    # ProductCode
    $this.CurrentState.Installer[0]['ProductCode'] = $InstallerFile2 | Read-ProductCodeFromMsi
    # AppsAndFeaturesEntries
    $this.CurrentState.Installer[0]['AppsAndFeaturesEntries'] = @(
      [ordered]@{
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
