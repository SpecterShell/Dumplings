$Object1 = Invoke-WebRequest -Uri $Global:DumplingsStorage.AGTEKAppInstallerSource.components.reveal.appinstaller | Read-ResponseContent | ConvertFrom-Xml

# Version
$this.CurrentState.Version = $Object1.AppInstaller.MainPackage.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Global:DumplingsStorage.AGTEKAppInstallerSource.components.reveal.msix
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = $Global:DumplingsStorage.AGTEKDownloadPage.SelectSingleNode('//tr[contains(./td[@class="td-filename"], "Reveal_")]')

      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
        [regex]::Match($Object2.SelectSingleNode('./td[@class="td-release-date"]').InnerText, '(\d{1,2}[-/]\d{1,2}[-/]\d{2,4})').Groups[1].Value,
        'M/d/yyyy',
        $null
      ).ToString('yyyy-MM-dd')

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = Join-Uri 'https://agtek.com/services-support/product-downloads/' $Object2.SelectSingleNode('./following-sibling::tr[contains(./td[@class="td-filename"], "Version Notes") and not(contains(./td[@class="td-filename"], "Classify"))]/td[@class="td-button"]/a').Attributes['href'].Value
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
