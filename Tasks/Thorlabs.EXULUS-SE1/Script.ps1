$Object1 = (Invoke-WebRequest -Uri 'https://www.thorlabs.com/api/software_pages/check_updates?ItemID=EXULUS' | Read-ResponseContent | ConvertFrom-Xml).ItemID.SoftwarePkg.Where({ $_.DownloadLink -match 'EXULUS-SE1' }, 'First')[0]

# Version
$this.CurrentState.Version = $Object1.VersionNumber

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl         = $InstallerUrl = $Object1.DownloadLink.Replace('//thin01mstroc282prod.dxcloud.episerver.net/', '//media.thorlabs.com/')
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = "$($InstallerUrl | Split-Path -LeafBase).exe"
    }
  )
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.ReleaseDate | Get-Date -Format 'yyyy-MM-dd'

      # LicenseUrl (en-US)
      # $this.CurrentState.Locale += [ordered]@{
      #   Locale = 'en-US'
      #   Key    = 'LicenseUrl'
      #   Value  = Join-Uri $InstallerUrl 'License.zip'
      # }
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
