# x86
$Object1 = Invoke-RestMethod -Uri 'https://s3-ap-southeast-2.amazonaws.com/redactdownload.objective.com/Objective_Redact_x86.json'

# x64
$Object2 = Invoke-RestMethod -Uri 'https://s3-ap-southeast-2.amazonaws.com/redactdownload.objective.com/Objective_Redact_x64.json'

if ($Object1.Details.Version -ne $Object2.Details.Version) {
  $this.Log("x86 version: $($Object1.Details.Version)")
  $this.Log("x64 version: $($Object2.Details.Version)")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Object2.Details.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = 'https://s3-ap-southeast-2.amazonaws.com/redactdownload.objective.com/Objective_Redact_x86.msi'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = 'https://s3-ap-southeast-2.amazonaws.com/redactdownload.objective.com/Objective_Redact_x64.msi'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.Details.Date | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

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
