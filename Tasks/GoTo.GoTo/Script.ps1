$Prefix = 'https://goto-desktop.goto.com/'
$Object1 = Invoke-RestMethod -Uri "${Prefix}latest.yml" | ConvertFrom-Yaml

$PrefixMachine = 'https://goto-desktop.goto.com/machine/'
$Object2 = Invoke-RestMethod -Uri "${PrefixMachine}latest.yml" | ConvertFrom-Yaml

if ($Object1.version -ne $Object2.version) {
  $this.Log("Inconsistent versions: User: $($Object1.version), Machine: $($Object2.version)", 'Error')
  return
}

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'nullsoft'
  Scope         = 'user'
  InstallerUrl  = Join-Uri $Prefix $Object1.files[0].url
}
# $this.CurrentState.Installer += [ordered]@{
#   InstallerType = 'nullsoft'
#   Scope         = 'machine'
#   InstallerUrl  = Join-Uri $PrefixMachine $Object2.files[0].url
# }
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'wix'
  Scope         = 'machine'
  InstallerUrl  = "https://goto-desktop.goto.com/GoToSetupMachine-$($this.CurrentState.Version)-ia32.msi"
  ProductCode   = 'b5746384-3503-4fbf-824a-0a42d1bd0639'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  Scope         = 'machine'
  InstallerUrl  = "https://goto-desktop.goto.com/GoToSetupMachine-$($this.CurrentState.Version)-x64.msi"
  ProductCode   = 'b5746384-3503-4fbf-824a-0a42d1bd0639'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.releaseDate | Get-Date -AsUTC
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
