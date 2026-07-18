$Object1 = (Invoke-RestMethod -Uri 'https://updates.perforce.com/static/P4V/P4V.json').versions | Where-Object -Property 'platform' -EQ -Value 'ntx64' | Sort-Object -Property { @([int]$_.major, [int]$_.minor) } -Bottom 1

# Version
$this.CurrentState.Version = "$($Object1.major -replace '^20').$($Object1.minor)"

# Installer
$this.CurrentState.Installer += $Installer = [ordered]@{
  InstallerType = 'wix'
  InstallerUrl  = "https://www.perforce.com/downloads/perforce/r$($this.CurrentState.Version)/bin.ntx64/p4vinst64.msi"
}
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'burn'
  InstallerUrl  = "https://www.perforce.com/downloads/perforce/r$($this.CurrentState.Version)/bin.ntx64/p4vinst64.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
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
