$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://cdn.caramba-switcher.com/files/win/CarambaSwitcherClassicSetup-latest.exe'
}

$Result = $this.CheckInstallerUpdates(@{
    Validator   = 'Auto'
    ReadVersion = { param($Path) Read-FileVersionFromExe -Path $Path }
  })
$this.CompleteInstallerUpdates($Result)
