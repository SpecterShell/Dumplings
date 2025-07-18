function Read-Installer {
  $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
  # Version
  $this.CurrentState.Version = $InstallerFile | Read-ProductVersionFromMsi
  # InstallerSha256
  $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
  # ProductCode
  $this.CurrentState.Installer[0]['ProductCode'] = $InstallerFile | Read-ProductCodeFromMsi
  # AppsAndFeaturesEntries
  $this.CurrentState.Installer[0]['AppsAndFeaturesEntries'] = @(
    [ordered]@{
      UpgradeCode = $InstallerFile | Read-UpgradeCodeFromMsi
    }
  )
  Remove-Item -Path $InstallerFile -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
}

function Get-ReleaseNotes {
  try {
    if ($Global:DumplingsStorage.Contains('Backup4all') -and $Global:DumplingsStorage.Backup4all.Contains($this.CurrentState.Version)) {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Global:DumplingsStorage.Backup4all[$this.CurrentState.Version].ReleaseTime | Get-Date -AsUTC

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Global:DumplingsStorage.Backup4all[$this.CurrentState.Version].ReleaseNotes
      }
    } else {
      $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
    }
  } catch {
    $_ | Out-Host
    $this.Log($_, 'Warning')
  }
}

# Installer
$this.CurrentState.Installer += $InstallerMSI = [ordered]@{
  InstallerType = 'wix'
  InstallerUrl  = 'https://download.backup4all.com/download/setup/b4asetup.msi'
}
$Object1 = Invoke-WebRequest -Uri $InstallerMSI.InstallerUrl -Method Head
# Last Modified
$this.CurrentState.LastModified = $Object1.Headers.'Last-Modified'[0]

$this.CurrentState.Installer += $InstallerEXE = [ordered]@{
  InstallerType = 'burn'
  InstallerUrl  = 'https://download.backup4all.com/download/setup/b4asetup-9.exe'
}
$Object2 = Invoke-WebRequest -Uri $InstallerEXE.InstallerUrl -Method Head
# Last Modified
$this.CurrentState.LastModifiedEXE = $Object2.Headers.'Last-Modified'[0]


# Case 0: Force submit the manifest
if ($Global:DumplingsPreference.Contains('Force')) {
  $this.Log('Skip checking states', 'Info')

  Read-Installer
  Get-ReleaseNotes

  $this.Print()
  $this.Write()
  $this.Message()
  if ($this.CurrentState.Version.Split('.')[0] -ne $this.Config.WinGetIdentifier.Split('.')[-1]) {
    $this.Log('Major version update. The WinGet package needs to be updated', 'Error')
  } else {
    $this.Submit()
  }
  return
}

# Case 1: The task is new
if ($this.Status.Contains('New')) {
  $this.Log('New task', 'Info')

  Read-Installer
  Get-ReleaseNotes

  $this.Print()
  $this.Write()
  return
}

# Case 2: The Last Modified is unchanged
if ([datetime]$this.CurrentState.LastModified -eq [datetime]$this.LastState.LastModified) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest (WiX)", 'Info')
  return
} elseif ([datetime]$this.CurrentState.LastModified -lt [datetime]$this.LastState.LastModified) {
  $this.Log("The last modified datetime from the current state `"$($this.CurrentState.LastModified)`" is older than the one from the last state `"$($this.LastState.LastModified)`" (WiX)", 'Warning')
  return
}
if ([datetime]$this.CurrentState.LastModifiedEXE -eq [datetime]$this.LastState.LastModifiedEXE) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest (EXE)", 'Info')
  return
} elseif ([datetime]$this.CurrentState.LastModifiedEXE -lt [datetime]$this.LastState.LastModifiedEXE) {
  $this.Log("The last modified datetime from the current state `"$($this.CurrentState.LastModifiedEXE)`" is older than the one from the last state `"$($this.LastState.LastModifiedEXE)`" (EXE)", 'Warning')
  return
}

Read-Installer

# Case 3: The current state has an invalid version
if ([string]::IsNullOrWhiteSpace($this.CurrentState.Version)) {
  throw 'The current state has an invalid version'
}

Get-ReleaseNotes

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
    $this.Message()
    if ($this.CurrentState.Version.Split('.')[0] -ne $this.Config.WinGetIdentifier.Split('.')[-1]) {
      $this.Log('Major version update. The WinGet package needs to be updated', 'Error')
    } else {
      $this.Submit()
    }
  }
  # Case 5: The Last Modified and the SHA256 have changed, but the version is not
  Default {
    $this.Log('The Last Modified and the SHA256 have changed, but the version is not', 'Info')
    $this.Config.IgnorePRCheck = $true
    $this.Print()
    $this.Write()
    $this.Message()
    if ($this.CurrentState.Version.Split('.')[0] -ne $this.Config.WinGetIdentifier.Split('.')[-1]) {
      $this.Log('Major version update. The WinGet package needs to be updated', 'Error')
    } else {
      $this.Submit()
    }
  }
}
