$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl -Uri 'https://download.winamp.com/winamp/winamp_latest_full.exe'
}

$Result = $this.CheckInstallerUpdates(@{
    Validator   = 'LastModified'
    ReadVersion = { param($Path) Read-ProductVersionFromNSIS -Path $Path }
  })
$this.CompleteInstallerUpdates($Result)
