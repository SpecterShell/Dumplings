function Read-Installer {
  $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
  $this.CurrentState.Installer[0].InstallerSha256 = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
  # Version
  $this.CurrentState.Version = ($InstallerFile | Read-FileVersionRawFromExe).ToString(3)
  # Installer
  $this.CurrentState.Installer += [ordered]@{
    Architecture        = 'x86'
    InstallerType       = 'zip'
    NestedInstallerType = 'wix'
    InstallerUrl        = "https://download.teamviewer.com/download/version_$($this.CurrentState.Version.Split('.')[0])x/update/Update_msi_$($this.CurrentState.Version).zip"
  }
  $this.CurrentState.Installer += [ordered]@{
    Architecture        = 'x64'
    InstallerType       = 'zip'
    NestedInstallerType = 'wix'
    InstallerUrl        = "https://download.teamviewer.com/download/version_$($this.CurrentState.Version.Split('.')[0])x/update/Update_msi_$($this.CurrentState.Version)_x64.zip"
  }
}

function Get-ReleaseNotes {
  try {
    $Object2 = curl -fsSLA $DumplingsInternetExplorerUserAgent "https://whatsnew.teamviewer.com/en/whatsnew/teamviewer-client/$($this.CurrentState.Version.Replace('.', '-'))/full.json" | Join-String -Separator "`n" | ConvertFrom-Json

    # ReleaseNotes (en-US)
    $Task.CurrentState.Locale += [ordered]@{
      Locale = 'en-US'
      Key    = 'ReleaseNotes'
      Value  = @"
New Features
$($Object2.changelog.features.html | ConvertFrom-Html | Get-TextContent)

Improvements
$($Object2.changelog.improvements.html | ConvertFrom-Html | Get-TextContent)

Bugfixes
$($Object2.changelog.bugfixes.html | ConvertFrom-Html | Get-TextContent)
"@ | Format-Text
    }
  } catch {
    $_ | Out-Host
    $this.Log($_, 'Warning')
  }

  try {
    $Object3 = curl -fsSLA $DumplingsInternetExplorerUserAgent "https://whatsnew.teamviewer.com/de/whatsnew/teamviewer-client/$($this.CurrentState.Version.Replace('.', '-'))/full.json" | Join-String -Separator "`n" | ConvertFrom-Json

    # ReleaseNotes (de-DE)
    $Task.CurrentState.Locale += [ordered]@{
      Locale = 'de-DE'
      Key    = 'ReleaseNotes'
      Value  = @"
New Features
$($Object3.changelog.features.html | ConvertFrom-Html | Get-TextContent)

Improvements
$($Object3.changelog.improvements.html | ConvertFrom-Html | Get-TextContent)

Bugfixes
$($Object3.changelog.bugfixes.html | ConvertFrom-Html | Get-TextContent)
"@ | Format-Text
    }
  } catch {
    $_ | Out-Host
    $this.Log($_, 'Warning')
  }
}

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'nullsoft'
  InstallerUrl  = 'https://download.teamviewer.com/download/version_15x/TeamViewer_Setup.exe'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = 'https://download.teamviewer.com/download/version_15x/TeamViewer_Setup_x64.exe'
}

# Last Modified
$this.CurrentState.LastModified = (Invoke-WebRequest -Uri $this.CurrentState.Installer[0].InstallerUrl -Method Head).Headers.'Last-Modified'[0]

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
  $this.Log("The version $($this.LastState.Version) from the last state is the latest", 'Info')
  return
} elseif ([datetime]$this.CurrentState.LastModified -lt [datetime]$this.LastState.LastModified) {
  $this.Log("The last modified datetime from the current state `"$($this.CurrentState.LastModified)`" is older than the one from the last state `"$($this.LastState.LastModified)`"", 'Warning')
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
