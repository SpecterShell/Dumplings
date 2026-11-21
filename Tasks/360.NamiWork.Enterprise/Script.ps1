$Object1 = Invoke-WebRequest -Uri 'https://www.namiwork.cn/'

# The enterprise page hardcodes the installer URLs in its assistant chunk
$Object2 = Invoke-WebRequest -Uri "https://qcdn.zhaomi.cn/assistant/$([regex]::Match($Object1.Content, 'assets/index-[^"''<>]+\.js').Value)"
$Object3 = Invoke-WebRequest -Uri "https://qcdn.zhaomi.cn/assistant/$([regex]::Match($Object2.Content, 'assets/src-[^"''<>]+\.js').Value)"

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = [regex]::Match($Object3.Content, 'https://sedl\.360tpcdn\.com/se/namiworkent_[\d.]+_setup\.exe').Value
}

$Result = $this.CheckInstallerUpdates(@{
    Validator   = 'LastModified'
    ReadVersion = { param($Path) Read-ProductVersionFromExe -Path $Path }
  })
$this.CompleteInstallerUpdates($Result)
