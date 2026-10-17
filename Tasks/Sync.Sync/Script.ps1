$Object1 = Invoke-WebRequest -Uri 'https://www10.sync.com/install/'

# Version
$Version = [regex]::Match($Object1.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href -match 'sync-installer' -and $_.href -match '/download/win/' } catch {} }, 'First')[0].href, '(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = "https://www10.sync.com/download/sync-packages/win/$Version/cur/latest-x86.msi"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://www10.sync.com/download/sync-packages/win/$Version/cur/latest.msi"
}

# The MSI ProductVersion carries a per-architecture fourth build component; the package uses the common three-part version.
$Result = $this.CheckInstallerUpdates(@{
    Validator   = 'LastModified'
    ReadVersion = { param($Path) (Read-ProductVersionFromMsi -Path $Path).Split('.')[0..2] -join '.' }
  })
$this.CompleteInstallerUpdates($Result)
