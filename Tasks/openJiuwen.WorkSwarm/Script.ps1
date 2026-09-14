$Object1 = Invoke-RestMethod -Uri 'https://openjiuwen.com/api/downloads/versions?skip=0&limit=100'

# The latest desktop release of the WorkSwarm component
$Object2 = $Object1.items.Where({ $_.isLatest }, 'First')[0]

# Version
$this.CurrentState.Version = [regex]::Match($Object2.label, '(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object2.downloads.windows.x86_64[0].url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.release_date
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
