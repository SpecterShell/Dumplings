$Prefix = 'https://download.todesktop.com/200527auaqaacsy/'

$Object1 = Invoke-RestMethod -Uri "${Prefix}latest.yml?noCache=$(Get-Random)" | ConvertFrom-Yaml

# Version
$this.CurrentState.Version = $Object1.version
$ShortVersion = $Object1.Version.Split('.')[0..2] -join '.'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'nullsoft'
  InstallerUrl  = $Prefix + $Object1.files[0].url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'wix'
  InstallerUrl  = "https://dl.todesktop.com/200527auaqaacsy/versions/${ShortVersion}/windows/msi/ia32"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = "https://dl.todesktop.com/200527auaqaacsy/versions/${ShortVersion}/windows/msi/x64"
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
