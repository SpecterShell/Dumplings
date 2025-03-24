$Uri1 = 'https://crisisgoapp.s3.amazonaws.com/Windows/CrisisGo_latest.msi'
$Object1 = Invoke-WebRequest -Uri $Uri1 -Method Head
# ETag
$ETag = $Object1.Headers.ETag[0]

# Case 0: Force submit the manifest
if ($Global:DumplingsPreference.Contains('Force')) {
  $this.Log('Skip checking states', 'Info')

  # ETag
  $this.CurrentState.ETag = @($ETag)

  $InstallerFile = Get-TempFile -Uri $Uri1
  # Version
  $this.CurrentState.Version = $InstallerFile | Read-ProductVersionFromMsi
  # InstallerSha256
  $this.CurrentState.InstallerSha256 = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash

  try {
    $Uri2 = "https://crisisgoapp.s3.amazonaws.com/Windows/CrisisGo_$($this.CurrentState.Version.Split('.')[0..2] -join '.').msi"
    $null = Invoke-WebRequest -Uri $Uri2 -Method Head
    # Installer
    $this.CurrentState.Installer += [ordered]@{
      InstallerUrl = $Uri2
    }
    # Mode
    $this.CurrentState.Mode = $true
  } catch {
    $this.Log("${Uri2} doesn't exist, fallback to ${Uri1}", 'Warning')
    # Installer
    $this.CurrentState.Installer += [ordered]@{
      InstallerUrl           = $Uri1
      InstallerSha256        = $this.CurrentState.InstallerSha256
      ProductCode            = $InstallerFile | Read-ProductCodeFromMsi
      AppsAndFeaturesEntries = @(
        [ordered]@{
          UpgradeCode = $InstallerFile | Read-UpgradeCodeFromMsi
        }
      )
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

  # ETag
  $this.CurrentState.ETag = @($ETag)

  $InstallerFile = Get-TempFile -Uri $Uri1
  # Version
  $this.CurrentState.Version = $InstallerFile | Read-ProductVersionFromMsi
  # InstallerSha256
  $this.CurrentState.InstallerSha256 = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash

  try {
    $Uri2 = "https://crisisgoapp.s3.amazonaws.com/Windows/CrisisGo_$($this.CurrentState.Version.Split('.')[0..2] -join '.').msi"
    $null = Invoke-WebRequest -Uri $Uri2 -Method Head
    # Installer
    $this.CurrentState.Installer += [ordered]@{
      InstallerUrl = $Uri2
    }
    # Mode
    $this.CurrentState.Mode = $true
  } catch {
    $this.Log("${Uri2} doesn't exist, fallback to ${Uri1}", 'Warning')
    # Installer
    $this.CurrentState.Installer += [ordered]@{
      InstallerUrl           = $Uri1
      InstallerSha256        = $this.CurrentState.InstallerSha256
      ProductCode            = $InstallerFile | Read-ProductCodeFromMsi
      AppsAndFeaturesEntries = @(
        [ordered]@{
          UpgradeCode = $InstallerFile | Read-UpgradeCodeFromMsi
        }
      )
    }
    # Mode
    $this.CurrentState.Mode = $false
  }

  $this.Print()
  $this.Write()
  return
}

if ($ETag -in $this.LastState.ETag) {
  # The ETag is not changed, so let's check if the alternative installer URL exists
  if ($this.LastState.Mode -eq $true) {
    # If the alternative installer URL exists, don't fallback to the main one
    $this.Log("The version $($this.LastState.Version) from the last state is the latest", 'Info')
    return
  } else {
    # Version
    $this.CurrentState.Version = $this.LastState.Version

    try {
      $Uri2 = "https://crisisgoapp.s3.amazonaws.com/Windows/CrisisGo_$($this.CurrentState.Version.Split('.')[0..2] -join '.').msi"
      $null = Invoke-WebRequest -Uri $Uri2 -Method Head
      # Installer
      $this.CurrentState.Installer += [ordered]@{
        InstallerUrl = $Uri2
      }
      # InstallerSha256
      $this.CurrentState.InstallerSha256 = $this.LastState.InstallerSha256
      # Mode
      $this.CurrentState.Mode = $true

      # Case 2: Detected an alternative installer URL
      $this.Log('An alternative installer URL is detected', 'Info')
      $this.Print()
      $this.Write()
      return
    } catch {
      # Case 3: The ETag is not changed, and the alternative installer URL doesn't exist
      return
    }
  }
} else {
  # The ETag has changed, but there is a chance that the hash is actually unchanged, so let's check it
  $InstallerFile = Get-TempFile -Uri $Uri1
  # Version
  $this.CurrentState.Version = $InstallerFile | Read-ProductVersionFromMsi
  # InstallerSha256
  $this.CurrentState.InstallerSha256 = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash

  if ($this.CurrentState.InstallerSha256 -eq $this.LastState.InstallerSha256) {
    $this.Log('The ETag has changed, but the hash is not', 'Info')
    # ETag
    $this.CurrentState.ETag = $this.LastState.ETag + $ETag

    if ($this.LastState.Mode -eq $true) {
      # Case 4: The ETag has changed, but the hash is not, and the alternative installer URL already exists
      $this.Log("The version $($this.LastState.Version) from the last state is the latest", 'Info')

      # Installer
      $this.CurrentState.Installer += [ordered]@{
        InstallerUrl = $this.LastState.Installer[0].InstallerUrl
      }
      # Mode
      $this.CurrentState.Mode = $true

      $this.Write()
      return
    } else {
      try {
        # Case 5: The ETag has changed, but the hash is not, while an alternative installer URL is detected
        $Uri2 = "https://crisisgoapp.s3.amazonaws.com/Windows/CrisisGo_$($this.CurrentState.Version.Split('.')[0..2] -join '.').msi"
        $null = Invoke-WebRequest -Uri $Uri2 -Method Head
        # Installer
        $this.CurrentState.Installer += [ordered]@{
          InstallerUrl = $Uri2
        }
        # Mode
        $this.CurrentState.Mode = $true

        $this.Log('An alternative installer URL is detected', 'Info')
        $this.Print()
        $this.Write()
        return
      } catch {
        # Case 6: The ETag has changed, but the hash is not, and the alternative installer URL doesn't exist

        # Installer
        $this.CurrentState.Installer += [ordered]@{
          InstallerUrl           = $Uri1
          InstallerSha256        = $this.CurrentState.InstallerSha256
          ProductCode            = $InstallerFile | Read-ProductCodeFromMsi
          AppsAndFeaturesEntries = @(
            [ordered]@{
              UpgradeCode = $InstallerFile | Read-UpgradeCodeFromMsi
            }
          )
        }
        # Mode
        $this.CurrentState.Mode = $false

        $this.Write()
        return
      }
    }

  } else {
    $this.Log('Both the ETag and the hash have changed', 'Info')
    # ETag
    $this.CurrentState.ETag = @($ETag)

    try {
      # The ETag and the hash have changed, while the alternative installer URL exists
      $Uri2 = "https://crisisgoapp.s3.amazonaws.com/Windows/CrisisGo_$($this.CurrentState.Version.Split('.')[0..2] -join '.').msi"
      $null = Invoke-WebRequest -Uri $Uri2 -Method Head
      # Installer
      $this.CurrentState.Installer += [ordered]@{
        InstallerUrl = $Uri2
      }
      # Mode
      $this.CurrentState.Mode = $true
    } catch {
      # The ETag and the hash have changed, but the alternative installer URL doesn't exist
      $this.Log("${Uri2} doesn't exist, fallback to ${Uri1}", 'Warning')
      # Installer
      $this.CurrentState.Installer += [ordered]@{
        InstallerUrl           = $Uri1
        InstallerSha256        = $this.CurrentState.InstallerSha256
        ProductCode            = $InstallerFile | Read-ProductCodeFromMsi
        AppsAndFeaturesEntries = @(
          [ordered]@{
            UpgradeCode = $InstallerFile | Read-UpgradeCodeFromMsi
          }
        )
      }
      # Mode
      $this.CurrentState.Mode = $false
    }
  }

  switch -Regex ($this.Check()) {
    # Case 8: The installer URL has changed
    'Changed|Updated|Rollbacked' {
      $this.Print()
      $this.Write()
      $this.Message()
    }
    # Case 9: The ETag, the hash and the version have changed
    'Updated|Rollbacked' {
      $this.Submit()
    }
    # Case 7: The ETag and the hash have changed, but the version is not
    Default {
      $this.Log('The ETag and the hash have changed, but the version is not', 'Info')
      $this.Config.IgnorePRCheck = $true
      $this.Print()
      $this.Write()
      $this.Message()
      $this.Submit()
    }
  }
}
