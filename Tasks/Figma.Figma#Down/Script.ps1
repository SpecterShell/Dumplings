function Read-Installer {
  $InstallerFile = Get-TempFile -Uri 'https://desktop.figma.com/win/FigmaSetup.exe'
  # Version
  $this.CurrentState.Version = $InstallerFile | Read-ProductVersionFromExe
  # InstallerSha256
  $this.CurrentState.InstallerSha256 = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
  Remove-Item -Path $InstallerFile -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'

  # Installer
  $this.CurrentState.Installer += [ordered]@{
    Architecture  = 'x64'
    InstallerType = 'exe'
    InstallerUrl  = "https://desktop.figma.com/win/build/Figma-$($this.CurrentState.Version).exe"
  }
  $this.CurrentState.Installer += [ordered]@{
    Architecture  = 'arm64'
    InstallerType = 'exe'
    InstallerUrl  = "https://desktop.figma.com/win-arm/build/Figma-$($this.CurrentState.Version).exe"
  }
  $this.CurrentState.Installer += $Installer = [ordered]@{
    Architecture  = 'x64'
    InstallerType = 'wix'
    InstallerUrl  = "https://desktop.figma.com/win/build/Figma-$($this.CurrentState.Version).msi"
  }
  $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
  # ProductCode
  $Installer['ProductCode'] = "$($InstallerFile | Read-ProductCodeFromMsi).msq"
}

function Send-Manifest {
  $ToSubmit = $false

  $Mutex = [System.Threading.Mutex]::new($false, 'DumplingsSubmitLockFigma')
  $Mutex.WaitOne(30000) | Out-Null
  if (-not $Global:DumplingsStorage.Contains("Figma-$($this.CurrentState.Version)-ToSubmit")) {
    $Global:DumplingsStorage["Figma-$($this.CurrentState.Version)-ToSubmit"] = $ToSubmit = $true
  }
  $Mutex.ReleaseMutex()
  $Mutex.Dispose()

  if ($ToSubmit) {
    $this.Submit()
  } else {
    $this.Log('Another task is submitting manifests for this package', 'Warning')
  }
}

$Object1 = Invoke-WebRequest -Uri 'https://desktop.figma.com/win/FigmaSetup.exe' -Method Head
$ETag = $Object1.Headers.ETag[0]

# Case 0: Force submit the manifest
if ($Global:DumplingsPreference.Contains('Force')) {
  $this.Log('Skip checking states', 'Info')

  # ETag
  $this.CurrentState.ETag = @($ETag)

  Read-Installer

  $this.Print()
  $this.Write()
  $this.Message()
  Send-Manifest
  return
}

# Case 1: The task is new
if ($this.Status.Contains('New')) {
  $this.Log('New task', 'Info')

  # ETag
  $this.CurrentState.ETag = @($ETag)

  Read-Installer

  $this.Print()
  Send-Manifest
  return
}

# Case 2: The ETag is unchanged
if ($ETag -in $this.LastState.ETag) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest (Global)", 'Info')
  return
}

Read-Installer

# Case 3: The current state has an invalid version
if ([string]::IsNullOrWhiteSpace($this.CurrentState.Version)) {
  throw 'The current state has an invalid version'
}

# Case 4: The ETag has changed, but the SHA256 is not
if ($this.CurrentState.InstallerSha256 -eq $this.LastState.InstallerSha256) {
  $this.Log('The ETag has changed, but the SHA256 is not', 'Info')

  # ETag
  $this.CurrentState.ETag = $this.LastState.ETag + $ETag

  $this.Write()
  return
}

# ETag
$this.CurrentState.ETag = @($ETag)

switch -Regex ($this.Check()) {
  # Case 6: The ETag, the SHA256 and the version have changed
  'Updated|Rollbacked' {
    $this.Print()
    $this.Write()
    $this.Message()
    Send-Manifest
  }
  # Case 5: The ETag and the SHA256 have changed, but the version is not
  default {
    $this.Log('The ETag and the SHA256 have changed, but the version is not', 'Info')
    $this.Config.IgnorePRCheck = $true
    $this.Print()
    $this.Write()
    $this.Message()
    Send-Manifest
  }
}
