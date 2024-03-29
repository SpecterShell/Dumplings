$Prefix = 'https://download.gigabyte.com/FileList/Swhttp/LiveUpdate4/GCC/Sidekick/'

$Object1 = Invoke-RestMethod -Uri "${Prefix}ver2.ini" | ConvertFrom-Ini

# Version
$this.CurrentState.Version = $Object1.Info.Ver

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "${Prefix}$($Object1.Info.ApName)_$($this.CurrentState.Version).exe"
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.Info.Date | Get-Date -Format 'yyyy-MM-dd'

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
