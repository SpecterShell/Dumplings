$Uri1 = 'https://down.360safe.com/se/360namiai_setup_x64.exe'
$Object1 = Invoke-WebRequest -Uri $Uri1 -Method Head
# Hash
$this.CurrentState.LastModified = $Object1.Headers.'Last-Modified'[0]

# Case 0: Force submit the manifest
if ($Global:DumplingsPreference.Contains('Force')) {
  $this.Log('Skip checking states', 'Info')

  $InstallerFile = Get-TempFile -Uri $Uri1
  # Version
  $this.CurrentState.Version = $InstallerFile | Read-ProductVersionFromExe
  # InstallerSha256
  $this.CurrentState.InstallerSha256 = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash

  try {
    $Uri2 = "https://down.360safe.com/se/360namiai$($this.CurrentState.Version).exe"
    $null = Invoke-WebRequest -Uri $Uri2 -Method Head
    # Installer
    $this.CurrentState.Installer += [ordered]@{
      InstallerUrl = $Uri2
      ProductCode  = "Freedom $($this.CurrentState.Version)"
    }
    # Mode
    $this.CurrentState.Mode = $true
  } catch {
    $this.Log("${Uri2} doesn't exist, fallback to ${Uri1}", 'Warning')
    # Installer
    $this.CurrentState.Installer += [ordered]@{
      InstallerUrl    = $Uri1
      InstallerSha256 = $this.CurrentState.InstallerSha256
      ProductCode     = "Freedom $($this.CurrentState.Version)"
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
  # InstallerSha256
  $this.CurrentState.InstallerSha256 = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash

  try {
    $Uri2 = "https://down.360safe.com/se/360namiai$($this.CurrentState.Version).exe"
    $null = Invoke-WebRequest -Uri $Uri2 -Method Head
    # Installer
    $this.CurrentState.Installer += [ordered]@{
      InstallerUrl = $Uri2
      ProductCode  = "Freedom $($this.CurrentState.Version)"
    }
    # Mode
    $this.CurrentState.Mode = $true
  } catch {
    $this.Log("${Uri2} doesn't exist, fallback to ${Uri1}", 'Warning')
    # Installer
    $this.CurrentState.Installer += [ordered]@{
      InstallerUrl    = $Uri1
      InstallerSha256 = $this.CurrentState.InstallerSha256
      ProductCode     = "Freedom $($this.CurrentState.Version)"
    }
    # Mode
    $this.CurrentState.Mode = $false
  }

  $this.Print()
  $this.Write()
  return
}

if ([datetime]$this.CurrentState.LastModified -le [datetime]$this.LastState.LastModified) {
  # The Last Modified is unchanged, so let's check if the alternative installer URL exists
  if ($this.LastState.Mode -eq $true) {
    # If the alternative installer URL exists, don't fallback to the main one
    $this.Log("The version $($this.LastState.Version) from the last state is the latest", 'Info')
    return
  } else {
    # Version
    $this.CurrentState.Version = $this.LastState.Version
    # InstallerSha256
    $this.CurrentState.InstallerSha256 = $this.LastState.InstallerSha256

    try {
      $Uri2 = "https://down.360safe.com/se/360namiai$($this.CurrentState.Version).exe"
      $null = Invoke-WebRequest -Uri $Uri2 -Method Head
      # Installer
      $this.CurrentState.Installer += [ordered]@{
        InstallerUrl = $Uri2
        ProductCode  = "Freedom $($this.CurrentState.Version)"
      }
      # Mode
      $this.CurrentState.Mode = $true

      # Case 2: The Last Modified is unchanged, but an alternative installer URL is detected
      $this.Log('An alternative installer URL is detected', 'Info')
      $this.Print()
      $this.Write()
      return
    } catch {
      # Case 3: The Last Modified is unchanged, and the alternative installer URL doesn't exist
      return
    }
  }
} else {
  # The Last Modified has changed, but there is a chance that the hash is actually unchanged, so let's check it
  $InstallerFile = Get-TempFile -Uri $Uri1
  # Version
  $this.CurrentState.Version = $InstallerFile | Read-ProductVersionFromExe
  # InstallerSha256
  $this.CurrentState.InstallerSha256 = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash

  if ($this.CurrentState.InstallerSha256 -eq $this.LastState.InstallerSha256) {
    $this.Log('The Last Modified has changed, but the SHA256 is not', 'Info')

    if ($this.LastState.Mode -eq $true) {
      # Case 4: The Last Modified has changed, but the SHA256 is not, and the alternative installer URL already exists
      $this.Log("The version $($this.LastState.Version) from the last state is the latest", 'Info')

      # Installer
      $this.CurrentState.Installer = $this.LastState.Installer
      # Mode
      $this.CurrentState.Mode = $true

      $this.Write()
      return
    } else {
      try {
        # Case 5: The Last Modified has changed, but the SHA256 is not, while an alternative installer URL is detected
        $Uri2 = "https://down.360safe.com/se/360namiai$($this.CurrentState.Version).exe"
        $null = Invoke-WebRequest -Uri $Uri2 -Method Head
        # Installer
        $this.CurrentState.Installer += [ordered]@{
          InstallerUrl = $Uri2
          ProductCode  = "Freedom $($this.CurrentState.Version)"
        }
        # Mode
        $this.CurrentState.Mode = $true

        $this.Log('An alternative installer URL is detected', 'Info')
        $this.Print()
        $this.Write()
        return
      } catch {
        # Case 6: The Last Modified has changed, but the SHA256 is not, and the alternative installer URL doesn't exist
        # Installer
        $this.CurrentState.Installer += [ordered]@{
          InstallerUrl    = $Uri1
          InstallerSha256 = $this.CurrentState.InstallerSha256
          ProductCode     = "Freedom $($this.CurrentState.Version)"
        }
        # Mode
        $this.CurrentState.Mode = $false

        $this.Write()
        return
      }
    }
  } else {
    $this.Log('Both the Last Modified and the SHA256 have changed', 'Info')

    try {
      # The Last Modified and the SHA256 have changed, while the alternative installer URL exists
      $Uri2 = "https://down.360safe.com/se/360namiai$($this.CurrentState.Version).exe"
      $null = Invoke-WebRequest -Uri $Uri2 -Method Head
      # Installer
      $this.CurrentState.Installer += [ordered]@{
        InstallerUrl = $Uri2
        ProductCode  = "Freedom $($this.CurrentState.Version)"
      }
      # Mode
      $this.CurrentState.Mode = $true
    } catch {
      # The Last Modified and the SHA256 have changed, but the alternative installer URL doesn't exist
      $this.Log("${Uri2} doesn't exist, fallback to ${Uri1}", 'Warning')
      # Installer
      $this.CurrentState.Installer += [ordered]@{
        InstallerUrl    = $Uri1
        InstallerSha256 = $this.CurrentState.InstallerSha256
        ProductCode     = "Freedom $($this.CurrentState.Version)"
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
    # Case 9: The Last Modified, the SHA256 and the version have changed
    'Updated|Rollbacked' {
      $this.Submit()
    }
    # Case 7: The Last Modified and the SHA256 have changed, but the version is not
    default {
      $this.Log('The Last Modified and the SHA256 have changed, but the version is not', 'Info')
      $this.Config.IgnorePRCheck = $true
      $this.Print()
      $this.Write()
      $this.Message()
      $this.Submit()
    }
  }
}
