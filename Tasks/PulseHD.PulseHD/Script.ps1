$Uri1 = 'https://storage.googleapis.com/pulsehd/PulseHD Setup.exe'
$Uri2 = 'https://storage.googleapis.com/pulsehd/PulseHD.msi'
$Object1 = Invoke-WebRequest -Uri $Uri1 -Method Head
# Hash
$this.CurrentState.Hash = $Object1.Headers.'x-goog-hash'.Where({ $_.StartsWith('md5=') }, 'First')[0] -replace '^md5='

# Case 0: Force submit the manifest
if ($Global:DumplingsPreference.Contains('Force')) {
  $this.Log('Skip checking states', 'Info')

  $InstallerFile = Get-TempFile -Uri $Uri1
  # Version
  $this.CurrentState.Version = $InstallerFile | Read-ProductVersionFromExe

  try {
    $UriA = "https://storage.googleapis.com/pulsehd/PulseHD Setup $($this.CurrentState.Version).exe"
    $null = Invoke-WebRequest -Uri $UriA -Method Head
    # Installer
    $this.CurrentState.Installer += [ordered]@{
      InstallerType = 'nullsoft'
      InstallerUrl  = $UriA
    }
    $this.CurrentState.Installer += [ordered]@{
      InstallerType = 'wix'
      InstallerUrl  = "https://storage.googleapis.com/pulsehd/PulseHD $($this.CurrentState.Version).msi"
    }
    # Mode
    $this.CurrentState.Mode = $true
  } catch {
    $this.Log("${UriA} doesn't exist, fallback to ${Uri1}", 'Warning')
    # Installer
    $this.CurrentState.Installer += [ordered]@{
      InstallerType   = 'nullsoft'
      InstallerUrl    = $Uri1
      InstallerSha256 = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    }
    $this.CurrentState.Installer += [ordered]@{
      InstallerType = 'wix'
      InstallerUrl  = $Uri2
    }
    # Mode
    $this.CurrentState.Mode = $false
  }

  $this.Print()
  $this.Write()
  $this.Message()
  $this.Submit()
  return
}

# Case 1: The task is new
if ($this.Status.Contains('New')) {
  $this.Log('New task', 'Info')

  $InstallerFile = Get-TempFile -Uri $Uri1
  # Version
  $this.CurrentState.Version = $InstallerFile | Read-ProductVersionFromExe

  try {
    $UriA = "https://storage.googleapis.com/pulsehd/PulseHD Setup $($this.CurrentState.Version).exe"
    $null = Invoke-WebRequest -Uri $UriA -Method Head
    # Installer
    $this.CurrentState.Installer += [ordered]@{
      InstallerType = 'nullsoft'
      InstallerUrl  = $UriA
    }
    $this.CurrentState.Installer += [ordered]@{
      InstallerType = 'wix'
      InstallerUrl  = "https://storage.googleapis.com/pulsehd/PulseHD $($this.CurrentState.Version).msi"
    }
    # Mode
    $this.CurrentState.Mode = $true
  } catch {
    $this.Log("${UriA} doesn't exist, fallback to ${Uri1}", 'Warning')
    # Installer
    $this.CurrentState.Installer += [ordered]@{
      InstallerType   = 'nullsoft'
      InstallerUrl    = $Uri1
      InstallerSha256 = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    }
    $this.CurrentState.Installer += [ordered]@{
      InstallerType = 'wix'
      InstallerUrl  = $Uri2
    }
    # Mode
    $this.CurrentState.Mode = $false
  }

  $this.Print()
  $this.Write()
  return
}

if ($this.CurrentState.Hash -eq $this.LastState.Hash) {
  # The hash is unchanged, so let's check if the alternative installer URL exists
  if ($this.LastState.Mode -eq $true) {
    # If the alternative installer URL exists, don't fallback to the main one
    $this.Log("The version $($this.LastState.Version) from the last state is the latest", 'Info')
    return
  } else {
    # Version
    $this.CurrentState.Version = $this.LastState.Version

    try {
      $UriA = "https://storage.googleapis.com/pulsehd/PulseHD Setup $($this.CurrentState.Version).exe"
      $null = Invoke-WebRequest -Uri $UriA -Method Head
      # Installer
      $this.CurrentState.Installer += [ordered]@{
        InstallerType = 'nullsoft'
        InstallerUrl  = $UriA
      }
      $this.CurrentState.Installer += [ordered]@{
        InstallerType = 'wix'
        InstallerUrl  = "https://storage.googleapis.com/pulsehd/PulseHD $($this.CurrentState.Version).msi"
      }
      # Mode
      $this.CurrentState.Mode = $true

      # Case 2: The hash is unchanged, but an alternative installer URL is detected
      $this.Log('An alternative installer URL is detected', 'Info')
      $this.Print()
      $this.Write()
      return
    } catch {
      # Case 3: The hash is unchanged, and the alternative installer URL doesn't exist
      return
    }
  }
} else {
  # The hash has changed
  $InstallerFile = Get-TempFile -Uri $Uri1
  # Version
  $this.CurrentState.Version = $InstallerFile | Read-ProductVersionFromExe

  try {
    # The hash has changed, while an alternative installer URL is detected
    $UriA = "https://storage.googleapis.com/pulsehd/PulseHD Setup $($this.CurrentState.Version).exe"
    $null = Invoke-WebRequest -Uri $UriA -Method Head
    # Installer
    $this.CurrentState.Installer += [ordered]@{
      InstallerType = 'nullsoft'
      InstallerUrl  = $UriA
    }
    $this.CurrentState.Installer += [ordered]@{
      InstallerType = 'wix'
      InstallerUrl  = "https://storage.googleapis.com/pulsehd/PulseHD $($this.CurrentState.Version).msi"
    }
    # Mode
    $this.CurrentState.Mode = $true
  } catch {
    # The hash has changed, but the alternative installer URL doesn't exist
    $this.Log("${UriA} doesn't exist, fallback to ${Uri1}", 'Warning')
    # Installer
    $this.CurrentState.Installer += [ordered]@{
      InstallerType   = 'nullsoft'
      InstallerUrl    = $Uri1
      InstallerSha256 = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    }
    $this.CurrentState.Installer += [ordered]@{
      InstallerType = 'wix'
      InstallerUrl  = $Uri2
    }
    # Mode
    $this.CurrentState.Mode = $false
  }

  switch -Regex ($this.Check()) {
    # Case 5: The installer URL has changed
    'Changed|Updated|Rollbacked' {
      $this.Print()
      $this.Write()
      $this.Message()
    }
    # Case 6: The hash and the version have changed
    'Updated|Rollbacked' {
      $this.Submit()
    }
    # Case 4: The hash has changed, but the version is not
    Default {
      $this.Log('The hash has changed, but the version is not', 'Info')
      $this.Config.IgnorePRCheck = $true
      $this.Print()
      $this.Write()
      $this.Message()
      $this.Submit()
    }
  }
}
