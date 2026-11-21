$Object1 = Invoke-RestMethod -Uri 'https://mobilecentraal.portnox.com/AgentpBackEndEnrollment/CheckForUpdates' -Method Post -Body (
  @{
    ClientVersion = $this.Status.Contains('New') ? '1.1.290' : $this.LastState.Version
    OsType        = 2
  } | ConvertTo-Json -Compress
) -ContentType 'application/json'

if ($null -eq $Object1.UpdateOptions) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

# Version
$this.CurrentState.Version = $Object1.UpdateOptions.LatestVersionNumber

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = 'https://clear.portnox.com/enduser/DownloadAgentPForOsAndPackageType?osType=2&packageType=Windows_x86'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = 'https://clear.portnox.com/enduser/DownloadAgentPForOsAndPackageType?osType=2&packageType=Windows_x64'
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
