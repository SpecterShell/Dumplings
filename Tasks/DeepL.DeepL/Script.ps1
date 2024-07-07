function Get-ReleaseTime {
  try {
    # ReleaseTime
    $this.CurrentState.ReleaseTime = $Object1.released | Get-Date -Format 'yyyy-MM-dd'
  } catch {
    $_ | Out-Host
    $this.Log($_, 'Warning')
  }
}

$Object1 = (Invoke-RestMethod -Uri 'https://appdownload.deepl.com/windows/0install/deepl.xml').SelectNodes('//*[name()="implementation" and @stability="stable"]') | Sort-Object -Property { $_.version -replace '\d+', { $_.Value.PadLeft(20) } } -Bottom 1

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = 'https://appdownload.deepl.com/windows/0install/DeepLSetup.exe'
}

$Object2 = Invoke-WebRequest -Uri $InstallerUrl -Method Head
# ETag
$this.CurrentState.ETag = $Object2.Headers.ETag[0]

# Case 1: The task is newly created
if ($this.Status.Contains('New')) {
  $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
  # InstallerSha256
  $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash

  Get-ReleaseTime

  $this.Print()
  $this.Write()
  return
}

# Case 2: The version was changed
switch -Regex ($this.Check()) {
  'Updated|Rollbacked' {
    $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # InstallerSha256
    $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash

    Get-ReleaseTime

    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
    return
  }
}

# Case 3: The version was not changed, and the installer file on the server was not updated
if ($this.CurrentState.ETag -eq $this.LastState.ETag) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest", 'Info')
  return
}

$InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
# InstallerSha256
$this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash

# Case 4: The installer file has an invalid version
if ([string]::IsNullOrWhiteSpace($this.CurrentState.Version)) {
  throw 'The current state has an invalid version'
}

Get-ReleaseTime

# Case 5: The installer file on the server was updated, but the hash didn't change
if ($this.CurrentState.Installer[0].InstallerSha256 -eq $this.LastState.Installer[0].InstallerSha256) {
  $this.Log('The ETag was changed, but the hash is the same', 'Info')
  $this.Write()
  return
}

# Case 6: The installer file on the server was updated, and the hash changed
$this.Log('The ETag and the hash were changed', 'Info')
$this.Config.IgnorePRCheck = $true
$this.Print()
$this.Write()
$this.Message()
$this.Submit()
