$Prefix = 'https://dl.bitsum.com/files/'
$Object1 = (Invoke-WebRequest -Uri "${Prefix}processlasso-releases.json").Content | ConvertFrom-Json -AsHashtable
$Object2 = $Object1.releases.Where({ $_.channel -eq 'beta' }, 'First')[0]

# Version
$this.CurrentState.Version = $Object2.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Prefix + 'beta/' + $Object2.files.Keys.Where({ $_ -match '32' }, 'First')[0]
}
# x64
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Prefix + 'beta/' + $Object2.files.Keys.Where({ $_ -match '64' }, 'First')[0]
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.date | Get-Date -Format 'yyyy-MM-dd'
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
