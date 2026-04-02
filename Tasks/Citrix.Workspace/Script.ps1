$Prefix = 'https://downloadplugins.citrix.com/ReceiverUpdates/Prod'

$Object1 = (Invoke-RestMethod -Uri "${Prefix}/catalog_win3.xml").Catalog.CatalogVersion.Installers.Where({ $_.name -eq '1CDF566D-B2C7-47CA-802F-6283C862E1D6' -or $_.name -eq 'WorkspaceApp' }, 'First')[0].Installer.Where({ $_.Stream -eq 'Current' }) | Sort-Object -Property { $_.Version -replace '\d+', { $_.Value.PadLeft(20) } } -Bottom 1

# Version
$this.CurrentState.Version = $Object1.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "${Prefix}$($Object1.DownloadURL)"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.StartDate | Get-Date -Format 'yyyy-MM-dd'
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
