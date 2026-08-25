$Object1 = $Global:DumplingsStorage.QuarkApps.ProductsRegister.ProductType.Where({ $_.Type -eq 'Updates' }, 'First')[0].ProductDetails.Where({ $_.ProductCode -eq 'com.quark.QuarkXPress.22' }, 'First')[0]

# Version
$this.CurrentState.Version = $Object1.PackageCode

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.PayloadID
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.PublishDate | Get-Date -Format 'yyyy-MM-dd'

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object1.UpdateDescription.en.Desc | Format-Text
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
