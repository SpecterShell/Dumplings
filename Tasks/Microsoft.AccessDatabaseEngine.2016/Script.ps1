$Object1 = (Invoke-WebRequest -Uri 'https://www.microsoft.com/en-us/download/details.aspx?id=54920').Content | Get-EmbeddedJson -StartsFrom 'window.__DLCDetails__=' | ConvertFrom-Json
# x86
$Object2 = $Object1.dlcDetailsView.downloadFile.Where({ $_.name -eq 'accessdatabaseengine.exe' }, 'First')[0]
# x64
$Object3 = $Object1.dlcDetailsView.downloadFile.Where({ $_.name -eq 'accessdatabaseengine_X64.exe' }, 'First')[0]

# Version
$this.CurrentState.Version = $Object3.datePublished | Get-Date | ConvertTo-UtcDateTime -Id 'UTC' | Get-Date -Format 'yyyy-MM-dd'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object2.url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object3.url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object3.datePublished | Get-Date | ConvertTo-UtcDateTime -Id 'UTC'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    foreach ($Installer in $this.CurrentState.Installer) {
      $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
      $InstallerFileExtracted = New-TempFolder
      7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile 'aceredist.msi' | Out-Host
      $InstallerFile2 = Join-Path $InstallerFileExtracted 'aceredist.msi'
      # RealVersion
      $this.CurrentState.RealVersion = $InstallerFile2 | Read-ProductVersionFromMsi
      # ProductCode
      $Installer['ProductCode'] = $InstallerFile2 | Read-ProductCodeFromMsi
      # AppsAndFeaturesEntries
      $Installer['AppsAndFeaturesEntries'] = @(
        [ordered]@{
          UpgradeCode   = $InstallerFile2 | Read-UpgradeCodeFromMsi
          InstallerType = 'wix'
        }
      )
      Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
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
