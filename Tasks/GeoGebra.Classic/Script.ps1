# Version + Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType          = 'exe'
  InstallerUrl           = $InstallerUrl = Get-RedirectedUrl -Uri 'https://download.geogebra.org/package/win-autoupdate'
  AppsAndFeaturesEntries = @(
    [ordered]@{
      DisplayVersion = $this.CurrentState.Version = [regex]::Match($InstallerUrl, '-(\d+-\d+-\d+)').Groups[1].Value.Replace('-', '.')
    }
  )
}
$this.CurrentState.Installer += $InstallerWix = [ordered]@{
  InstallerType = 'wix'
  InstallerUrl  = $InstallerUrl -replace '\.exe$', '.msi'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $InstallerFileWix = Get-TempFile -Uri $InstallerWix.InstallerUrl
    $InstallerWix['InstallerSha256'] = (Get-FileHash -Path $InstallerFileWix -Algorithm SHA256).Hash
    $InstallerWix['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        DisplayVersion = $InstallerFileWix | Read-ProductVersionFromMsi
        ProductCode    = $InstallerWix['ProductCode'] = $InstallerFileWix | Read-ProductCodeFromMsi
        UpgradeCode    = $InstallerFileWix | Read-UpgradeCodeFromMsi
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
