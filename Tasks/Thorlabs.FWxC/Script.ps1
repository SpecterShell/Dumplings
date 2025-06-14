$Object1 = Invoke-RestMethod -Uri 'https://www.thorlabs.com/software_pages/check_updates.cfm?ItemID=FW102C'

# Version
$this.CurrentState.Version = $Object1.ItemID.SoftwarePkg[0].VersionNumber

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl         = $InstallerUrl = $Object1.ItemID.SoftwarePkg[0].DownloadLink
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
      $this.CurrentState.ReleaseTime = $Object1.ItemID.SoftwarePkg[0].ReleaseDate | Get-Date -Format 'yyyy-MM-dd'
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
