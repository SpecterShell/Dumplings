$Query = @'
{
  product(
    id: "ca479cc2-0fb8-4ebf-8131-dcac2bfdc485"
    productType: application
    productVariant: release
  ) {
    ... on ProductApplication {
      latestVersion
      releaseDate
      whatIsNew
      assets(os: win) {
        packageFileRefreshUrl
        version
      }
    }
  }
}
'@

$Object1 = Invoke-RestMethod -Uri 'https://cosmos-customer-webservice.azurewebsites.net/graphql' -Method Post -Body (
  @{ query = $Query } | ConvertTo-Json -Compress
) -ContentType 'application/json'

# Version
$this.CurrentState.Version = $Object1.data.product.assets.version

$Object2 = Invoke-RestMethod -Uri $Object1.data.product.assets.packageFileRefreshUrl

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object2.Trim() | Split-Uri -LeftPart Path
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.data.product.releaseDate.ToUniversalTime()

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object1.data.product.whatIsNew | Convert-MarkdownToHtml | Get-TextContent | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    $InstallerFileExtracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile 'MuseHub.exe' | Out-Host
    $InstallerFile2 = Join-Path $InstallerFileExtracted 'MuseHub.exe'

    # InstallerSha256
    $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile2 | Read-ProductVersionFromExe

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
