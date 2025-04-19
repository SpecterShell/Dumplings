$Object1 = $Global:DumplingsStorage.AGTEKDownloadPage
$Object2 = $Object1.SelectSingleNode('//tr[contains(./td[@class="td-filename"], "MaterialsSA")]')

# Version
$this.CurrentState.Version = [regex]::Match($Object2.SelectSingleNode('./td[@class="td-version"]').InnerText, '(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object2.SelectSingleNode('./td[@class="td-button"]/a').Attributes['href'].Value
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
        [regex]::Match($Object2.SelectSingleNode('./td[@class="td-release-date"]').InnerText, '(\d{1,2}[-/]\d{1,2}[-/]\d{2,4})').Groups[1].Value,
        'M/d/yyyy',
        $null
      ).ToString('yyyy-MM-dd')
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
