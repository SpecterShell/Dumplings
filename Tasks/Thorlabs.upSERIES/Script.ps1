$Object1 = Invoke-RestMethod -Uri 'https://www.thorlabs.com/software_pages/check_updates.cfm?ItemID=upSERIES'

# Version
$this.CurrentState.Version = $Object1.ItemID.SoftwarePkg.VersionNumber

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.ItemID.SoftwarePkg.DownloadLink.Replace('\', '/')
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.ItemID.SoftwarePkg.ReleaseDate | Get-Date -Format 'yyyy-MM-dd'

      # LicenseUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'LicenseUrl'
        Value  = "https://www.thorlabs.com/software/MUC/upSERIES/upSERIES_V$($this.CurrentState.Version)/License.rtf"
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
