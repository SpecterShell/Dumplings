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
      $this.CurrentState.ReleaseTime = $Object1.data.availableProductSoftwareByPid.publishDate.ToUniversalTime()

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

    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromMsi

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
