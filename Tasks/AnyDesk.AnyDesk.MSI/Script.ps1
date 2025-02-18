function Read-Installer {
  $InstallerFile = Get-TempFile -Uri "$($this.CurrentState.Installer[0].InstallerUrl)?t=$(Get-Date -Format 'yyyyMMdd')"

  # Version
  $this.CurrentState.Version = $InstallerFile | Read-ProductVersionFromMsi
  # InstallerSha256
  $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
  # AppsAndFeaturesEntries + ProductCode
  $this.CurrentState.Installer[0]['AppsAndFeaturesEntries'] = @(
    [ordered]@{
      DisplayName = 'AnyDesk MSI'
      ProductCode = $this.CurrentState.Installer[0]['ProductCode'] = $InstallerFile | Read-ProductCodeFromMsi
      UpgradeCode = $InstallerFile | Read-UpgradeCodeFromMsi
    }
  )
}

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://download.anydesk.com/AnyDesk.msi'
}

$Object1 = Invoke-WebRequest -Uri $this.CurrentState.Installer[0].InstallerUrl -Method Head
# Last Modified
$this.CurrentState.LastModified = $Object1.Headers.'Last-Modified'[0]

# Case 0: Force submit the manifest
if ($Global:DumplingsPreference.Contains('Force')) {
  $this.Log('Skip checking states', 'Info')

  Read-Installer

  $this.Print()
  $this.Write()
  $this.CurrentState.Installer | ForEach-Object -Process { $_.InstallerUrl += "?t=$(Get-Date -Format 'yyyyMMdd')" }
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

# Case 2: The Last Modified is unchanged
if ([datetime]$this.CurrentState.LastModified -le [datetime]$this.LastState.LastModified) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest", 'Info')
  return
}

Read-Installer

# Case 3: The current state has an invalid version
if ([string]::IsNullOrWhiteSpace($this.CurrentState.Version)) {
  throw 'The current state has an invalid version'
}

# Case 4: The Last Modified has changed, but the SHA256 is not
if ($this.CurrentState.Installer[0].InstallerSha256 -eq $this.LastState.Installer[0].InstallerSha256) {
  $this.Log('The Last Modified has changed, but the SHA256 is not', 'Info')

  $this.Write()
  return
}

switch -Regex ($this.Check()) {
  # Case 6: The Last Modified, the SHA256 and the version have changed
  'Updated|Rollbacked' {
    $this.Print()
    $this.Write()
    $this.CurrentState.Installer | ForEach-Object -Process { $_.InstallerUrl += "?t=$(Get-Date -Format 'yyyyMMdd')" }
    $this.Message()
    $this.Submit()
  }
  # Case 5: The Last Modified and the SHA256 have changed, but the version is not
  Default {
    $this.Log('The Last Modified and the SHA256 have changed, but the version is not', 'Info')
    $this.Config.IgnorePRCheck = $true
    $this.Print()
    $this.Write()
    $this.CurrentState.Installer | ForEach-Object -Process { $_.InstallerUrl += "?t=$(Get-Date -Format 'yyyyMMdd')" }
    $this.Message()
    $this.Submit()
  }
}
