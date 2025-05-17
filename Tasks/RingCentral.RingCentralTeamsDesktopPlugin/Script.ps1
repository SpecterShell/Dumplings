$Object1 = Invoke-RestMethod -Uri 'https://teams.ringcentral.com/assets/desktop-plugin/rc/prod-v2/windows/build.yml' | ConvertFrom-Yaml

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'nullsoft'
  InstallerUrl  = Join-Uri 'https://teams.ringcentral.com/assets/desktop-plugin/rc/packages/windows/' $Object1.files.Where({ $_.url.Contains('ia32') }, 'First')[0].url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = Join-Uri 'https://teams.ringcentral.com/assets/desktop-plugin/rc/packages/windows/' $Object1.files.Where({ $_.url.Contains('x64') }, 'First')[0].url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'wix'
  InstallerUrl  = Join-Uri 'https://teams.ringcentral.com/assets/desktop-plugin/rc/packages/windows/' ($Object1.files.Where({ $_.url.Contains('ia32') }, 'First')[0].url -replace '(?<=RingCentralForTeamsDesktopPlugin-)', 'admin-' -replace '\.exe$', '.msi')
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = Join-Uri 'https://teams.ringcentral.com/assets/desktop-plugin/rc/packages/windows/' ($Object1.files.Where({ $_.url.Contains('x64') }, 'First')[0].url -replace '(?<=RingCentralForTeamsDesktopPlugin-)', 'admin-' -replace '\.exe$', '.msi')
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.releaseDate | Get-Date -AsUTC
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    foreach ($Installer in $this.CurrentState.Installer) {
      if ($Installer.InstallerType -eq 'wix') {
        $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
        # AppsAndFeaturesEntries
        $this.CurrentState.Installer[0]['AppsAndFeaturesEntries'] = @(
          [ordered]@{
            DisplayVersion = $InstallerFile | Read-ProductVersionFromMsi
            UpgradeCode    = $InstallerFile | Read-UpgradeCodeFromMsi
          }
        )
      }
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
