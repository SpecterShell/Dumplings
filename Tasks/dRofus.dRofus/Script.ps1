$Object1 = Invoke-WebRequest -Uri 'https://deploy.drofus.com/stable/RELEASES' | Read-ResponseContent | ConvertFrom-SquirrelReleases | Where-Object -FilterScript { -not $_.IsDelta } | Sort-Object -Property { $_.Version -creplace '\d+', { $_.Value.PadLeft(20) } } -Bottom 1

$VersionMatches = [regex]::Match($Object1.Filename, '(\d+(?:\.\d+)+)(?:-stable)?(-(\d+))?')

# Version
$this.CurrentState.Version = "$($VersionMatches.Groups[1].Value).$($VersionMatches.Groups[2].Success ? $VersionMatches.Groups[2].Value : '0')"

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'wix'
  InstallerUrl  = "https://deploy.drofus.com/stable/drofus-setup-$($VersionMatches.Groups[1].Value).msi"
}

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
