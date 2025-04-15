$Object1 = Invoke-RestMethod -Uri 'https://check.screenconnect.com/VersionCheck.axd' -Body @{
  Version      = $this.Status.Contains('New') ? '25.2.3.9216' : $this.LastState.Version
  IsPreRelease = $false
}

# Version
$this.CurrentState.Version = $Object1.VersionTestResult.LatestVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://d1kuyuqowve5id.cloudfront.net/ScreenConnect_$($this.CurrentState.Version)_Release.msi"
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
