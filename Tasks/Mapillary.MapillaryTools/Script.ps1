$Prefix = 'https://tools.mapillary.com/uploader/'

$Object1 = Invoke-RestMethod -Uri "${Prefix}latest-win32.yml?noCache=$(Get-Random)" | ConvertFrom-Yaml

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Prefix + $Object1.path
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.releaseDate | Get-Date -AsUTC

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
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
