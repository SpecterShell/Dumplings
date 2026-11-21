$Object1 = Invoke-WebRequest -Uri 'https://www.thorlabs.com/api/software_pages/check_updates?ItemID=TC200' | Read-ResponseContent | ConvertFrom-Xml

# Version
$this.CurrentState.Version = $Object1.ItemID.SoftwarePkg.VersionNumber

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.ItemID.SoftwarePkg.DownloadLink.Replace('//thin01mstroc282prod.dxcloud.episerver.net/', '//media.thorlabs.com/')
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # LicenseUrl (en-US)
      # $this.CurrentState.Locale += [ordered]@{
      #   Locale = 'en-US'
      #   Key    = 'LicenseUrl'
      #   Value  = "https://www.thorlabs.com/software/TC200/Software/License_$($this.CurrentState.Version).zip"
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
