$Uri = 'https://download.oracle.com/java/21/latest/jdk-21_windows-x64_bin.msi'
$InstallerSha256 = (Invoke-RestMethod -Uri "${Uri}.sha256").Trim().ToUpper()

# Case 0: Force submit the manifest
if ($Global:DumplingsPreference.Contains('Force')) {
  $this.Log('Skip checking states', 'Info')

  $InstallerFile = Get-TempFile -Uri $Uri
  # Version
  $this.CurrentState.Version = $InstallerFile | Read-ProductVersionFromMsi
  $ShortVersion = $this.CurrentState.Version.Split('.')[0..2] -join '.'
  # Installer
  $this.CurrentState.Installer += [ordered]@{
    InstallerUrl    = "https://download.oracle.com/java/21/archive/jdk-${ShortVersion}_windows-x64_bin.msi"
    InstallerSha256 = $InstallerSha256
  }
  # AppsAndFeaturesEntries + ProductCode
  $this.CurrentState.Installer[0]['AppsAndFeaturesEntries'] = @(
    [ordered]@{
      ProductCode = $this.CurrentState.Installer[0]['ProductCode'] = $InstallerFile | Read-ProductCodeFromMsi
      UpgradeCode = $InstallerFile | Read-UpgradeCodeFromMsi
    }
  )

  $this.Print()
  $this.Write()
  $this.Message()
  $this.Submit()
  return
}

# Case 1: The task is newly created
if ($this.Status.Contains('New')) {
  $this.Log('New task', 'Info')

  $InstallerFile = Get-TempFile -Uri $Uri
  # Version
  $this.CurrentState.Version = $InstallerFile | Read-ProductVersionFromMsi
  $ShortVersion = $this.CurrentState.Version.Split('.')[0..2] -join '.'
  # Installer
  $this.CurrentState.Installer += [ordered]@{
    InstallerUrl    = "https://download.oracle.com/java/21/archive/jdk-${ShortVersion}_windows-x64_bin.msi"
    InstallerSha256 = $InstallerSha256
  }
  # AppsAndFeaturesEntries + ProductCode
  $this.CurrentState.Installer[0]['AppsAndFeaturesEntries'] = @(
    [ordered]@{
      ProductCode = $this.CurrentState.Installer[0]['ProductCode'] = $InstallerFile | Read-ProductCodeFromMsi
      UpgradeCode = $InstallerFile | Read-UpgradeCodeFromMsi
    }
  )

  $this.Print()
  $this.Write()
  return
}

# Case 2: The SHA256 was not updated
if ($InstallerSha256 -eq $this.LastState.Installer[0].InstallerSha256) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest", 'Info')
  return
}

$InstallerFile = Get-TempFile -Uri $Uri
# Version
$this.CurrentState.Version = $InstallerFile | Read-ProductVersionFromMsi
$ShortVersion = $this.CurrentState.Version.Split('.')[0..2] -join '.'
# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl    = "https://download.oracle.com/java/21/archive/jdk-${ShortVersion}_windows-x64_bin.msi"
  InstallerSha256 = $InstallerSha256
}
# AppsAndFeaturesEntries + ProductCode
$this.CurrentState.Installer[0]['AppsAndFeaturesEntries'] = @(
  [ordered]@{
    ProductCode = $this.CurrentState.Installer[0]['ProductCode'] = $InstallerFile | Read-ProductCodeFromMsi
    UpgradeCode = $InstallerFile | Read-UpgradeCodeFromMsi
  }
)

# Case 3: The installer file has an invalid version
if ([string]::IsNullOrWhiteSpace($this.CurrentState.Version)) {
  throw 'The current state has an invalid version'
}

switch -Regex ($this.Check()) {
  # Case 5: The SHA256 and the version were updated
  'Updated|Rollbacked' {
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
  # Case 4: The SHA256 was updated, but the version wasn't
  Default {
    $this.Log('The SHA256 was changed, but the version is the same', 'Info')
    $this.Config.IgnorePRCheck = $true
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
}
