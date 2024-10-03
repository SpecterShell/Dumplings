# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://downloads.belarc.com/advisor/advisorinstaller.exe'
}

$Object1 = Invoke-WebRequest -Uri "$($this.CurrentState.Installer[0].InstallerUrl)?t=$(Get-Date -Format 'yyyyMMdd')" -Method Head
$ETag = $Object1.Headers.ETag[0]

# Case 0: Force submit the manifest
if ($Global:DumplingsPreference.Contains('Force')) {
  $this.Log('Skip checking states', 'Info')

  # ETag
  $this.CurrentState.ETag = @($ETag)

  $InstallerFile = Get-TempFile -Uri "$($this.CurrentState.Installer[0].InstallerUrl)?t=$(Get-Date -Format 'yyyyMMdd')"
  # Version
  $this.CurrentState.Version = ($InstallerFile | Read-FileVersionRawFromExe).ToString()
  # InstallerSha256
  $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash

  $this.Print()
  $this.Write()
  $this.CurrentState.Installer.ForEach({ $_.InstallerUrl += "?t=$(Get-Date -Format 'yyyyMMdd')" })
  $this.Message()
  $this.Submit()
  return
}

# Case 1: The task is newly created
if ($this.Status.Contains('New')) {
  $this.Log('New task', 'Info')

  # ETag
  $this.CurrentState.ETag = @($ETag)

  $InstallerFile = Get-TempFile -Uri "$($this.CurrentState.Installer[0].InstallerUrl)?t=$(Get-Date -Format 'yyyyMMdd')"
  # Version
  $this.CurrentState.Version = ($InstallerFile | Read-FileVersionRawFromExe).ToString()
  # InstallerSha256
  $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash

  $this.Print()
  $this.Write()
  return
}

# Case 2: The ETag was not updated
if ($ETag -in $this.LastState.ETag) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest", 'Info')
  return
}

$InstallerFile = Get-TempFile -Uri "$($this.CurrentState.Installer[0].InstallerUrl)?t=$(Get-Date -Format 'yyyyMMdd')"
# Version
$this.CurrentState.Version = ($InstallerFile | Read-FileVersionRawFromExe).ToString()
# InstallerSha256
$this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash

# Case 3: The installer file has an invalid version
if ([string]::IsNullOrWhiteSpace($this.CurrentState.Version)) {
  throw 'The current state has an invalid version'
}

# Case 4: The ETag was updated, but the hash wasn't
if ($this.CurrentState.Installer[0].InstallerSha256 -eq $this.LastState.Installer[0].InstallerSha256) {
  $this.Log('The ETag was changed, but the hash is the same', 'Info')

  # ETag
  $this.CurrentState.ETag = $this.LastState.ETag + $ETag

  $this.Write()
  return
}

# ETag
$this.CurrentState.ETag = @($ETag)

switch -Regex ($this.Check()) {
  # Case 6: The ETag, hash, and version were updated
  'Updated|Rollbacked' {
    $this.Print()
    $this.Write()
    $this.CurrentState.Installer.ForEach({ $_.InstallerUrl += "?t=$(Get-Date -Format 'yyyyMMdd')" })
    $this.Message()
    $this.Submit()
  }
  # Case 5: Both the ETag and the hash were updated, but the version wasn't
  Default {
    $this.Log('The ETag and the hash were changed, but the version is the same', 'Info')
    $this.Config.IgnorePRCheck = $true
    $this.Print()
    $this.Write()
    $this.CurrentState.Installer.ForEach({ $_.InstallerUrl += "?t=$(Get-Date -Format 'yyyyMMdd')" })
    $this.Message()
    $this.Submit()
  }
}
