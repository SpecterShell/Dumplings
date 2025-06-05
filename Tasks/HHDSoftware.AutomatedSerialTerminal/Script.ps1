function Read-Installer {
  $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
  $InstallerFileExtracted = New-TempFolder
  7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile 'config.ini' | Out-Host
  $Object2 = Join-Path $InstallerFileExtracted 'config.ini' | Get-Item | Get-Content -Raw | ConvertFrom-Ini
  # Version
  $this.CurrentState.Version = "$($Object2.Configuration.MAJOR).$($Object2.Configuration.MINOR).$($Object2.Configuration.REVISION).$($Object2.Configuration.BUILD)"
  # InstallerSha256
  $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
  Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
  Remove-Item -Path $InstallerFile -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
}

function Get-ReleaseNotes {
  try {
    $Object3 = Invoke-WebRequest -Uri 'https://hhdsoftware.com/serial-port-terminal/history' | ConvertFrom-Html

    $ReleaseNotesTitleNode = $Object3.SelectSingleNode("//div[@class='p-vh-item' and contains(.//div[@class='p-vh-item-header-title'], '$($this.CurrentState.Version)')]")
    if ($ReleaseNotesTitleNode) {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
        [regex]::Match($ReleaseNotesTitleNode.SelectSingleNode('.//div[@class="p-vh-item-header-title"]').InnerText, '(\d{1,2}/\d{1,2}/20\d{2})').Groups[1].Value,
        'M/dd/yyyy',
        $null
      ).ToString('yyyy-MM-dd')

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotesTitleNode.SelectNodes('.//div[@class="p-vh-item-main-title"]/following-sibling::node()') | Get-TextContent | Format-Text
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
$this.CurrentState.Installer += $Installer = [ordered]@{
  InstallerUrl = 'https://hhdsoftware.com/download/automated-serial-terminal.exe'
}
$Object1 = Invoke-WebRequest -Uri $Installer.InstallerUrl -Method Head -UserAgent $WinGetUserAgent
# Last Modified
$this.CurrentState.LastModified = $Object1.Headers.'Last-Modified'[0]

$this.CurrentState.Installer += $InstallerArm64 = [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = 'https://hhdsoftware.com/download/automated-serial-terminal-arm64.exe'
}
$Object2 = Invoke-WebRequest -Uri $InstallerArm64.InstallerUrl -Method Head
# Last Modified
$this.CurrentState.LastModifiedArm64 = $Object2.Headers.'Last-Modified'[0]

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
  $this.Log("The version $($this.LastState.Version) from the last state is the latest (x64)", 'Info')
  return
} elseif ([datetime]$this.CurrentState.LastModified -le [datetime]$this.LastState.LastModified) {
  $this.Log("The last modified datetime from the current state `"$($this.CurrentState.LastModified)`" is older than the one from the last state `"$($this.LastState.LastModified)`" (x64)", 'Warning')
  return
}
if ([datetime]$this.CurrentState.LastModifiedArm64 -le [datetime]$this.LastState.LastModifiedArm64) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest (arm64)", 'Info')
  return
} elseif ([datetime]$this.CurrentState.LastModifiedArm64 -lt [datetime]$this.LastState.LastModifiedArm64) {
  $this.Log("The last modified datetime from the current state `"$($this.CurrentState.LastModifiedArm64)`" is older than the one from the last state `"$($this.LastState.LastModifiedArm64)`" (arm64)", 'Warning')
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
  Default {
    $this.Log('The Last Modified and the SHA256 have changed, but the version is not', 'Info')
    $this.Config.IgnorePRCheck = $true
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
}
