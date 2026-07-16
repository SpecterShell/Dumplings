$Prefix = 'https://downloadplugins.citrix.com/ReceiverUpdates/Prod'
$Object1 = (Invoke-RestMethod -Uri "${Prefix}/catalog_win3.xml").Catalog.CatalogVersion.Installers.Where({ $_.name -eq '1CDF566D-B2C7-47CA-802F-6283C862E1D6' -or $_.name -eq 'WorkspaceApp' }, 'First')[0].Installer.Where({ $_.Stream -eq 'Current' }) | Sort-Object -Property { [ChunkVersion]($_.Version) } -Bottom 1
$Object2 = (Invoke-RestMethod -Uri "${Prefix}/catalog_win3_x64.xml").Catalog.CatalogVersion.Installers.Where({ $_.name -eq '1CDF566D-B2C7-47CA-802F-6283C862E1D6' -or $_.name -eq 'WorkspaceAppX64' }, 'First')[0].Installer.Where({ $_.Stream -eq 'Current' }) | Sort-Object -Property { [ChunkVersion]($_.Version) } -Bottom 1

if ($Object1.Version -ne $Object2.Version) {
  $this.Log("Inconsistent versions: x86: $($Object1.Version), x64: $($Object2.Version)", 'Error')
  return
}

# Version
$this.CurrentState.Version = $Object2.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = "${Prefix}$($Object1.DownloadURL)"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "${Prefix}$($Object2.DownloadURL)"
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
