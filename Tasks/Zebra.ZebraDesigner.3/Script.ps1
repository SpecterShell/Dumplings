$Object1 = (curl -fsSLA $DumplingsInternetExplorerUserAgent 'https://www.zebra.com/content/servlet/supportdownload/downloadsearch?pagePath=/content/zebra1/us/en/support-downloads/software/printer-software/zebra-designer-3-downloads' | Join-String -Separator "`n" | ConvertFrom-Json).Download.Where({ $_.productModel -contains 'ZebraDesigner 3' }, 'First')[0]

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://www.zebra.com' + $Object1.versionDownloadReferences[0].listingDownloadFiles[0].id
}

# Version
$this.CurrentState.Version = [regex]::Match($Object1.versionDownloadReferences[0].downloadShortDisplayTitle, '(\d+(?:\.\d+){3,})').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.versionDownloadReferences[0].downloadReleaseDate.ToUniversalTime()

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = 'https://www.zebra.com' + ($Object1.versionDownloadReferences[0].helpfulLinksInformation | ConvertFrom-Html).SelectSingleNode('//a[contains(text(), "Release Notes")]').Attributes['href'].Value
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
