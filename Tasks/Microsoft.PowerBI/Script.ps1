$StartDate = Get-Date -Date (Get-Date -AsUTC -Format 'yyyy-MM')
$EndDate = $this.LastState.Contains('LastDate') ? (Get-Date -Date $this.LastState.LastDate) : (Get-Date -Date '2024-10')

$Found = $false
for ($Date = $StartDate; $Date -gt $EndDate; $Date = $Date.AddMonths(-1)) {
  $InstallerUrl = "https://download.microsoft.com/download/8/8/0/880BCA75-79DD-466A-927D-1ABF1F5454B0/PBIDesktopSetup-$($Date.ToString('yyyy-MM'))_x64.exe"
  $this.Log("Probing ${InstallerUrl}", 'Info')
  $Object1 = Invoke-WebRequest -Uri $InstallerUrl -Method Head -SkipHttpErrorCheck
  if ($Object1.StatusCode -eq 200) {
    $InstallerFile = Get-TempFile -Uri $InstallerUrl

    # Version
    $this.CurrentState.Version = $InstallerFile | Read-ProductVersionFromExe
    # Installer
    $this.CurrentState.Installer += [ordered]@{
      Architecture = 'x64'
      InstallerUrl = $InstallerUrl
    }
    # LastDate
    $this.CurrentState.LastDate = $Date.ToString('yyyy-MM')

    $Found = $true
    break
  }
}

if (-not $Found) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest", 'Info')
  $this.CurrentState = $this.LastState
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
