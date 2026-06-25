$Object1 = Invoke-RestMethod -Uri 'https://www.rsiguard.com/cgi-bin/update.php' -Body @{
  vers     = $this.Status.Contains('New') ? 'v6.2.16.0' : "v$($this.LastState.Version)"
  cc       = '1'
  mfc      = '1'
  platform = 'win'
} | Split-LineEndings

# Version
$this.CurrentState.Version = $Object1[1].Trim()

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1[2].Trim() | Split-Uri -LeftPart 'Path'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromMsi

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
