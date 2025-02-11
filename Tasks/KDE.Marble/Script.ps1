$Object1 = Invoke-WebRequest -Uri 'https://marble.kde.org/install.php'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href.Contains('x64') } catch {} }, 'First')[0].href
}

$VersionMatches = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '((\d+(?:\.\d+)+)(?:-\d+)?)')

# Version
$this.CurrentState.Version = $VersionMatches.Groups[1].Value

# RealVersion
$this.CurrentState.RealVersion = $VersionMatches.Groups[2].Value

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
