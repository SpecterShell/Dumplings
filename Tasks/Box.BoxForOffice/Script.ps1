function Read-Installer {
  $InstallerFile = Get-TempFile -Uri $InstallerMSI.InstallerUrl
  # Version
  $this.CurrentState.Version = $InstallerFile | Read-ProductVersionFromMsi
  # InstallerSha256
  $InstallerMSI['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm 'SHA256').Hash
  # ProductCode
  $InstallerMSI['ProductCode'] = $InstallerFile | Read-ProductCodeFromMsi
  $InstallerEXE['ProductCode'] = "Box for Office $($this.CurrentState.Version)"
  # AppsAndFeaturesEntries
  $InstallerMSI['AppsAndFeaturesEntries'] = @(
    [ordered]@{
      UpgradeCode = $InstallerFile | Read-UpgradeCodeFromMsi
    }
  )
  Remove-Item -Path $InstallerFile -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
}

# MSI
$this.CurrentState.Installer += $InstallerMSI = [ordered]@{
  InstallerType = 'msi'
  InstallerUrl  = 'https://e3.boxcdn.net/box-installers/boxforoffice/currentrelease/BoxForOffice.msi'
}
$Object1 = Invoke-WebRequest -Uri $InstallerMSI.InstallerUrl -Method Head
$ETag = $Object1.Headers.ETag[0]

# EXE
$this.CurrentState.Installer += $InstallerEXE = [ordered]@{
  InstallerType = 'exe'
  InstallerUrl  = 'https://e3.boxcdn.net/box-installers/boxforoffice/currentrelease/BoxForOffice.exe'
}
$Object2 = Invoke-WebRequest -Uri $InstallerEXE.InstallerUrl -Method Head
$ETagEXE = $Object2.Headers.ETag[0]

# Case 0: Force submit the manifest
if ($Global:DumplingsPreference.Contains('Force')) {
  $this.Log('Skip checking states', 'Info')

  # ETag
  $this.CurrentState.ETag = @($ETag)
  $this.CurrentState.ETagEXE = @($ETagEXE)

  Read-Installer

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
  $this.CurrentState.ETagEXE = @($ETagEXE)

  Read-Installer

  $this.Print()
  $this.Write()
  return
}

# Case 2: The ETag is unchanged
if ($ETag -in $this.LastState.ETag) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest (MSI)", 'Info')
  return
}
if ($ETagEXE -in $this.LastState.ETagEXE) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest (EXE)", 'Info')
  return
}

Read-Installer

# Case 3: The current state has an invalid version
if ([string]::IsNullOrWhiteSpace($this.CurrentState.Version)) {
  throw 'The current state has an invalid version'
}

# Case 4: The ETag has changed, but the SHA256 is not
if ($this.CurrentState.Installer[0].InstallerSha256 -eq $this.LastState.Installer[0].InstallerSha256) {
  $this.Log('The ETag has changed, but the SHA256 is not', 'Info')

  # ETag
  $this.CurrentState.ETag = $this.LastState.ETag + $ETag
  $this.CurrentState.ETagEXE = $this.LastState.ETagEXE + $ETagEXE

  $this.Write()
  return
}

# ETag
$this.CurrentState.ETag = @($ETag)
$this.CurrentState.ETagEXE = @($ETagEXE)

switch -Regex ($this.Check()) {
  # Case 6: The ETag, the SHA256 and the version have changed
  'Updated|Rollbacked' {
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
  # Case 5: The ETag and the SHA256 have changed, but the version is not
  Default {
    $this.Log('The ETag and the SHA256 have changed, but the version is not', 'Info')
    $this.Config.IgnorePRCheck = $true
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
}
