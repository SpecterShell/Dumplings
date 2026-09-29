$Query = @'
{
  availableProductSoftwareByPid(pid: "{pid}", releaseChannel:"marketing") {
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

# x64
$Object1 = Invoke-RestMethod -Uri 'https://api.silica-prod01.io.lens.poly.com/graphql' -Method Post -Body (
  @{ query = $Query.Replace('{pid}', 'lens-desktop-windows') } | ConvertTo-Json -Compress
) -ContentType 'application/json'
$VersionX64 = $Object1.data.availableProductSoftwareByPid.version
# arm64
$Object2 = Invoke-RestMethod -Uri 'https://api.silica-prod01.io.lens.poly.com/graphql' -Method Post -Body (
  @{ query = $Query.Replace('{pid}', 'lens-desktop-windows-arm') } | ConvertTo-Json -Compress
) -ContentType 'application/json'
$VersionARM64 = $Object2.data.availableProductSoftwareByPid.version

if ($VersionX64 -ne $VersionARM64) {
  $this.Log("Inconsistent versions: x64: $VersionX64, arm64: $VersionARM64", 'Error')
  return
}

# Version
$this.CurrentState.Version = $VersionX64

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.data.availableProductSoftwareByPid.productBuild.archiveUrl
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = $Object2.data.availableProductSoftwareByPid.productBuild.archiveUrl
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.data.availableProductSoftwareByPid.publishDate.ToUniversalTime()
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = Invoke-RestMethod -Uri 'https://info.lens.poly.com/lens-dt-rn/atom.xml'

      $ReleaseNotesObject = $Object2.Where({ $_.title.'#cdata-section'.Contains($this.CurrentState.Version.Split('.')[0..2] -join '.') }, 'First')
      if ($ReleaseNotesObject) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObject[0].content.'#cdata-section' | ConvertFrom-Html | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
