$Page = Invoke-WebRequest -Uri 'https://dyna.oasys-software.com/download/'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = $Page.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href -match '/oasys\d+_\d+_x64_setup\.exe$' } catch {} }, 'First')[0].href
}

$Result = $this.CheckInstallerUpdates(@{
  Validator   = 'ETag'
  ReadVersion = {
    param($Path, $Installer)
    $Match = [regex]::Match($Installer.InstallerUrl, '/oasys(\d+)_(\d+)_x64_setup\.exe$')
    return "$($Match.Groups[1].Value).$($Match.Groups[2].Value)"
  }
})
$this.CompleteInstallerUpdates($Result)
