$Prefix = 'https://releases.app.herohealth.net/production/win32/x64/'

$Object1 = Invoke-WebRequest -Uri "${Prefix}RELEASES" | Read-ResponseContent | ConvertFrom-SquirrelReleases | Where-Object -FilterScript { -not $_.IsDelta } | Sort-Object -Property { [RawVersion]$_.Version } -Bottom 1

# Version
$this.CurrentState.Version = $Object1.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'exe'
  InstallerUrl  = Join-Uri $Prefix 'HeroSidekickSetup.exe'
}
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'wix'
  InstallerUrl  = Join-Uri $Prefix 'HeroSidekickSetup.msi'
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
