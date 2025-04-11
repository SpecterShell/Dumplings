$Object1 = $Global:DumplingsStorage.CarrierDownloadPage.SelectSingleNode('//tr[contains(./td[1], "PLV Pro")]')

# Version
$this.CurrentState.Version = [regex]::Match($Object1.SelectSingleNode('./td[2]').InnerText, '(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.SelectSingleNode('./td[3]//a').Attributes['href'].Value
  ProductCode  = "Carrier PLV Pro v$($this.CurrentState.Version)"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $null
      }
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $Object1.SelectSingleNode('./td[4]//a').Attributes['href'].Value
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
