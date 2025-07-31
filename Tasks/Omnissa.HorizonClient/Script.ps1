$Object1 = (Invoke-RestMethod -Uri 'https://customerconnect.omnissa.com/channel/public/api/v1.0/products/getRelatedDLGList?category=virtual_desktop_and_apps&product=omnissa_horizon_clients&version=8&dlgType=PRODUCT_BINARY').dlgEditionsLists.Where({ $_.name -eq 'Omnissa Horizon Client for Windows' }, 'First')[0].dlgList
$Object2 = Invoke-RestMethod -Uri "https://customerconnect.omnissa.com/channel/public/api/v1.0/dlg/details?downloadGroup=$($Object1.code)&productId=$($Object1.productId)&rPId=$($Object1.releasePackageId)"

# Version
$this.CurrentState.Version = $Object2.downloadFiles[0].version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object2.downloadFiles[0].thirdPartyDownloadUrl
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.downloadFiles[0].releaseDate | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

    try {
      $Object3 = Invoke-RestMethod -Uri "https://customerconnect.omnissa.com/channel/public/api/v1.0/products/getDLGHeader?downloadGroup=$($Object1.code)&productId=$($Object1.productId)"
      $Object4 = $Object3.dlg.documentation | ConvertTo-HtmlDecodedText | ConvertFrom-Html

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $ReleaseNotesUrl = $Object4.SelectSingleNode('//a').Attributes['href'].DeEntitizeValue
      }

      $Object5 = Invoke-RestMethod -Uri $ReleaseNotesUrl.Replace('docs.omnissa.com', 'docs-be.omnissa.com/api')

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object5.topic_html | ConvertFrom-Html | Get-TextContent | Format-Text
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
