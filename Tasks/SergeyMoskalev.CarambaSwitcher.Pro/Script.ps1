$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://cdn.caramba-switcher.com/files/win/CarambaSwitcherProSetup-latest.exe'
}

$Result = $this.CheckInstallerUpdates(@{
  Validator   = 'LastModified'
  ReadVersion = { param($Path) Read-FileVersionFromExe -Path $Path }
})
$this.CompleteInstallerUpdates($Result)
