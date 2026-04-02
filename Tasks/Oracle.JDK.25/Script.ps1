function Read-Installer {
  $InstallerFile = Get-TempFile -Uri $Uri
  # Version
  $this.CurrentState.Version = $InstallerFile | Read-ProductVersionFromMsi
  $ShortVersion = $this.CurrentState.Version -replace '(\.0)+$'
  # Installer
  $this.CurrentState.Installer += [ordered]@{
    InstallerUrl    = "https://download.oracle.com/java/25/archive/jdk-${ShortVersion}_windows-x64_bin.msi"
    InstallerSha256 = $InstallerSha256
    ProductCode     = $InstallerFile | Read-ProductCodeFromMsi
  }
  Remove-Item -Path $InstallerFile -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
}

$Uri = 'https://download.oracle.com/java/25/latest/jdk-25_windows-x64_bin.msi'
$InstallerSha256 = (Invoke-RestMethod -Uri "${Uri}.sha256").Trim().ToUpper()

# Case 0: Force submit the manifest
if ($Global:DumplingsPreference.Contains('Force')) {
  $this.Log('Skip checking states', 'Info')

  Read-Installer

  $this.Print()
  $this.Write()
  $this.Message()
  $this.Submit()
  return
}

# Case 1: The task is new
if ($this.Status.Contains('New')) {
  $this.Log('New task', 'Info')

  Read-Installer

  $this.Print()
  $this.Write()
  return
}

# Case 2: The SHA256 is unchanged
if ($InstallerSha256 -eq $this.LastState.Installer[0].InstallerSha256) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest", 'Info')
  return
}

Read-Installer

# Case 3: The current state has an invalid version
if ([string]::IsNullOrWhiteSpace($this.CurrentState.Version)) {
  throw 'The current state has an invalid version'
}

switch -Regex ($this.Check()) {
  # Case 5: The SHA256 and the version have changed
  'Updated|Rollbacked' {
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
  # Case 4: The SHA256 has changed, but the version is not
  Default {
    $this.Log('The SHA256 has changed, but the version is not', 'Info')
    $this.Config.IgnorePRCheck = $true
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
}
