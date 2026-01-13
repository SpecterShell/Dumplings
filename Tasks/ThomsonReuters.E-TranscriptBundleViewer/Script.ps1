$Prefix = 'https://www.thomsonreuters.com/en-us/help/legal-products-software-downloads'
$Object1 = Invoke-WebRequest -Uri $Prefix | ConvertFrom-Html
$Object2 = $Object1.SelectSingleNode('//div[@data-prop-page-title="Legal products software downloads"]')
$Object3 = $Object2.Attributes['data-prop-table-data-props'].DeEntitizeValue | ConvertFrom-Json
$Object4 = $Object3.Where({ $_.tableData[0].value -eq 'E-Transcript Bundle Viewer' }, 'First')[0]
# $Object5 = Invoke-RestMethod -Uri "$($Object2.Attributes['data-prop-file-download-url'].DeEntitizeValue)/files/download/$([uri]::EscapeDataString($Object4.tableData[3].link))" -Headers @{
#   Referer       = 'https://www.thomsonreuters.com/'
#   Authorization = 'Bearer thomson-reuters-help-center-external-user'
# }

# # Installer
# $this.CurrentState.Installer += [ordered]@{
#   InstallerUrl = $Object5.url
# }
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Prefix $Object4.tableData[3].link
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:_\d+)+)').Groups[1].Value.Replace('_', '.')

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object4.tableData[1].value | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    foreach ($Installer in $this.CurrentState.Installer) {
      $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
      $InstallerFileExtracted = $InstallerFile | Expand-InstallShield
      $InstallerFile2 = Join-Path $InstallerFileExtracted 'EBundleViewer.msi'
      # ProductCode
      $Installer['ProductCode'] = $InstallerFile2 | Read-ProductCodeFromMsi
      # AppsAndFeaturesEntries + ProductCode
      $Installer['AppsAndFeaturesEntries'] = @(
        [ordered]@{
          UpgradeCode   = $InstallerFile2 | Read-UpgradeCodeFromMsi
          InstallerType = 'msi'
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
