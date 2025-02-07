$Query = @'
{
  availableProductSoftwareByPid(pid: "lens-desktop-windows") {
    version
    publishDate
    releaseNotes(refresh: true) {
      header
      body
    }
    productBuild {
      archiveUrl
    }
  }
}
'@

$Object1 = Invoke-RestMethod -Uri 'https://api.silica-prod01.io.lens.poly.com/graphql' -Method Post -Body (
  @{ query = $Query } | ConvertTo-Json -Compress
) -ContentType 'application/json'

# Version
$this.CurrentState.Version = $Object1.data.availableProductSoftwareByPid.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.availableProductSoftwareByPid.productBuild.archiveUrl
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $OBject1.data.availableProductSoftwareByPid.publishDate.ToUniversalTime()

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object1.data.availableProductSoftwareByPid.releaseNotes.ForEach({ "$($_.header)`n$($_.body | Convert-MarkdownToHtml | Get-TextContent)" }) -join "`n`n" | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl

    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromMsi
    # InstallerSha256
    $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # AppsAndFeaturesEntries + ProductCode
    $this.CurrentState.Installer[0]['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        ProductCode = $this.CurrentState.Installer[0]['ProductCode'] = $InstallerFile | Read-ProductCodeFromMsi
        UpgradeCode = $InstallerFile | Read-UpgradeCodeFromMsi
      }
    )

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
