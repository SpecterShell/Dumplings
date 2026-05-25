$Object1 = Invoke-WebRequest -Uri $Global:DumplingsStorage.AGTEKAppInstallerSource.components.revealclassify.appinstaller | Read-ResponseContent | ConvertFrom-Xml

# Version
$this.CurrentState.Version = $Object1.AppInstaller.MainPackage.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Global:DumplingsStorage.AGTEKAppInstallerSource.components.revealclassify.msix
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = Join-Uri 'https://agtek.com/services-support/product-downloads/' $Global:DumplingsStorage.AGTEKDownloadPage.SelectSingleNode('//tr[contains(./td[@class="td-filename"], "Version Notes") and contains(./td[@class="td-filename"], "Reveal Classify")]/td[@class="td-button"]/a').Attributes['href'].Value
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
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
