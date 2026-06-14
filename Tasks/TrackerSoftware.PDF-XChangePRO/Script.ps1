$ProductSlug = 'pdf-xchange-pro'
$InstallerBaseName = 'Pro'

$Object1 = Invoke-WebRequest -Uri "https://www.pdf-xchange.com/product/${ProductSlug}"
$PageText = $Object1.Content -replace '<[^>]+>', ' ' -replace '\s+', ' '

# Version
$this.CurrentState.Version = [regex]::Match($PageText, 'Current version:\s*([\d.]+)').Groups[1].Value

$MajorVersion = [version]$this.CurrentState.Version | Select-Object -ExpandProperty Major

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'wix'
  InstallerUrl  = "https://downloads.pdf-xchange.com/$($this.CurrentState.Version)/${InstallerBaseName}V${MajorVersion}.x86.msi"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = "https://downloads.pdf-xchange.com/$($this.CurrentState.Version)/${InstallerBaseName}V${MajorVersion}.x64.msi"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'wix'
  InstallerUrl  = "https://downloads.pdf-xchange.com/$($this.CurrentState.Version)/${InstallerBaseName}V${MajorVersion}.ARM64.msi"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    foreach ($Installer in $this.CurrentState.Installer) {
      $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
      # AppsAndFeaturesEntries + ProductCode
      $Installer['AppsAndFeaturesEntries'] = @(
        [ordered]@{
          ProductCode   = $Installer['ProductCode'] = $InstallerFile | Read-ProductCodeFromMsi
          UpgradeCode   = $InstallerFile | Read-UpgradeCodeFromMsi
          InstallerType = 'wix'
        }
      )
    }

    # ReleaseNotesUrl (en-US)
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'en-US'
      Key    = 'ReleaseNotesUrl'
      Value  = "https://www.pdf-xchange.com/product/${ProductSlug}/history?build=$($this.CurrentState.Version)"
    }

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
