function Read-Installer {
  $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
  # Version
  $this.CurrentState.Version = $InstallerFile | Read-FileVersionFromExe
}

function Get-ReleaseNotes {
  try {
    $Object4 = $Object1.apps.Where({ $_.id -eq 'pairingtool' })[0].platforms.Where({ $_.title -eq 'Windows' })[0].changeLog.Where({ $_.version -eq ($this.CurrentState.Version.Split('.')[0..2] -join '.') })
    if ($Object4) {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object4[0].date | Get-Date -Format 'yyyy-MM-dd'

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object4[0].description | Format-Text
      }
    } else {
      $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
    }
  } catch {
    $_ | Out-Host
    $this.Log($_, 'Warning')
  }
}

$Object1 = Invoke-RestMethod -Uri 'https://www.idmelon.com/downloads/pairing_tool/meta.json'
$Object2 = $Object1.apps.Where({ $_.id -eq 'pairingtool' })[0].platforms.Where({ $_.title -eq 'Windows' })[0].versions.Where({ $_.title -eq 'Stable' })[0]

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object2.link
}

$Object3 = Invoke-WebRequest -Uri $this.CurrentState.Installer[0].InstallerUrl -Method Head
# Hash
$this.CurrentState.Hash = $Object3.Headers.'x-goog-hash'.Where({ $_.StartsWith('md5=') }, 'First')[0] -replace '^md5='

# Case 0: Force submit the manifest
if ($Global:DumplingsPreference.Contains('Force')) {
  $this.Log('Skip checking states', 'Info')

  Read-Installer
  Get-ReleaseNotes

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
  Get-ReleaseNotes

  $this.Print()
  $this.Write()
  return
}

# Case 2: The hash is unchanged
if ($this.CurrentState.Hash -eq $this.LastState.Hash) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest", 'Info')
  return
}

Read-Installer

# Case 3: The current state has an invalid version
if ([string]::IsNullOrWhiteSpace($this.CurrentState.Version)) {
  throw 'The current state has an invalid version'
}

Get-ReleaseNotes

switch -Regex ($this.Check()) {
  # Case 5: The hash and the version have changed
  'Updated|Rollbacked' {
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
  # Case 4: The hash has changed, but the version is not
  default {
    $this.Log('The hash has changed, but the version is not', 'Info')
    $this.Config.IgnorePRCheck = $true
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
}
