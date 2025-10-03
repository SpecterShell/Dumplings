function Read-Installer {
  $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
  # Version
  $this.CurrentState.Version = $InstallerFile | Read-FileVersionFromExe
  # InstallerSha256
  $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
  Remove-Item -Path $InstallerFile -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
}

function Get-ReleaseNotes {
  try {
    $Object4 = Invoke-RestMethod -Uri 'https://www.sqliteexpert.com/v5/sqliteexpert.version.js'

    if ($Object4.Contains($this.CurrentState.Version.Split('.')[0..2] -join '.')) {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match($Object4, '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
    } else {
      $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
    }
  } catch {
    $_ | Out-Host
    $this.Log($_, 'Warning')
  }

  try {
    $Object5 = Invoke-WebRequest -Uri 'https://www.sqliteexpert.com/history.html' | ConvertFrom-Html

    $ReleaseNotesTitleNode = $Object5.SelectSingleNode("//h3[contains(text(), '$($this.CurrentState.Version.Split('.')[0..1] -join '.')')]")
    if ($ReleaseNotesTitleNode) {
      # Remove unnecessary elements
      $Object5.SelectNodes('//i[@class="ion-android-checkbox"]').ForEach({ $_.Remove() })
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotesTitleNode.SelectNodes('./following-sibling::node()') | Get-TextContent | Format-Text
      }
    } else {
      $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
    }
  } catch {
    $_ | Out-Host
    $this.Log($_, 'Warning')
  }
}

$Prefix = 'https://www.sqliteexpert.com/download.html'
$Object1 = Invoke-WebRequest -Uri $Prefix

# x86
$this.CurrentState.Installer += $InstallerX86 = [ordered]@{
  Architecture = 'x86'
  InstallerUrl = Join-Uri $Prefix $Object1.Links.Where({ try { $_.href.EndsWith('.exe') -and -not $_.href.Contains('Pro') -and $_.href.Contains('32') } catch {} }, 'First')[0].href
}
$Object2 = Invoke-WebRequest -Uri $InstallerX86.InstallerUrl -Method Head
# Last Modified
$this.CurrentState.LastModified = $Object2.Headers.'Last-Modified'[0]

# x64
$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Join-Uri $Prefix $Object1.Links.Where({ try { $_.href.EndsWith('.exe') -and -not $_.href.Contains('Pro') -and $_.href.Contains('64') } catch {} }, 'First')[0].href
}
$Object3 = Invoke-WebRequest -Uri $InstallerX64.InstallerUrl -Method Head
# Last Modified
$this.CurrentState.LastModifiedX64 = $Object3.Headers.'Last-Modified'[0]

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

# Case 2: The Last Modified is unchanged
if ([datetime]$this.CurrentState.LastModified -eq [datetime]$this.LastState.LastModified) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest (x86)", 'Info')
  return
} elseif ([datetime]$this.CurrentState.LastModified -lt [datetime]$this.LastState.LastModified) {
  $this.Log("The last modified datetime from the current state `"$($this.CurrentState.LastModified)`" is older than the one from the last state `"$($this.LastState.LastModified)`" (x86)", 'Warning')
  return
}
if ([datetime]$this.CurrentState.LastModifiedX64 -eq [datetime]$this.LastState.LastModifiedX64) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest (x64)", 'Info')
  return
} elseif ([datetime]$this.CurrentState.LastModifiedX64 -lt [datetime]$this.LastState.LastModifiedX64) {
  $this.Log("The last modified datetime from the current state `"$($this.CurrentState.LastModifiedX64)`" is older than the one from the last state `"$($this.LastState.LastModifiedX64)`" (x64)", 'Warning')
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
    $this.Submit()
  }
  # Case 5: The Last Modified and the SHA256 have changed, but the version is not
  default {
    $this.Log('The Last Modified and the SHA256 have changed, but the version is not', 'Info')
    $this.Config.IgnorePRCheck = $true
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
}
