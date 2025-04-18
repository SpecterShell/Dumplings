function Read-Installer {
  $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
  # Version
  $this.CurrentState.Version = $InstallerFile | Read-ProductVersionFromExe
  # InstallerSha256
  $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm 'SHA256').Hash
  Remove-Item -Path $InstallerFile -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
}

# EXE
$this.CurrentState.Installer += $InstallerEXE = [ordered]@{
  InstallerType = 'nullsoft'
  InstallerUrl  = 'https://cp.serverdata.net/voice/pbx/TeamsWidgetReleases/Ascend/Latest-Win/ascend-teams-desktop-plugin.exe'
}
$Object1 = Invoke-WebRequest -Uri $InstallerEXE.InstallerUrl -Method Head
$ETag = $Object1.Headers.ETag[0]

# MSI x86
$this.CurrentState.Installer += $InstallerMSIx86 = [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'wix'
  InstallerUrl  = 'https://cp.serverdata.net/voice/pbx/TeamsWidgetReleases/Ascend/Latest-Win/ascend-teams-desktop-plugin-ia32.msi'
}
$Object2 = Invoke-WebRequest -Uri $InstallerMSIx86.InstallerUrl -Method Head
$ETagMSIx86 = $Object2.Headers.ETag[0]

# MSI x64
$this.CurrentState.Installer += $InstallerMSIx64 = [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = 'https://cp.serverdata.net/voice/pbx/TeamsWidgetReleases/Ascend/Latest-Win/ascend-teams-desktop-plugin-x64.msi'
}
$Object3 = Invoke-WebRequest -Uri $InstallerMSIx64.InstallerUrl -Method Head
$ETagMSIx64 = $Object3.Headers.ETag[0]

# Case 0: Force submit the manifest
if ($Global:DumplingsPreference.Contains('Force')) {
  $this.Log('Skip checking states', 'Info')

  # ETag
  $this.CurrentState.ETag = @($ETag)
  $this.CurrentState.ETagMSIx86 = @($ETagMSIx86)
  $this.CurrentState.ETagMSIx64 = @($ETagMSIx64)

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
  $this.CurrentState.ETagMSIx86 = @($ETagMSIx86)
  $this.CurrentState.ETagMSIx64 = @($ETagMSIx64)

  Read-Installer

  $this.Print()
  $this.Write()
  return
}

# Case 2: The ETag is unchanged
if ($ETag -in $this.LastState.ETag) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest (EXE)", 'Info')
  return
}
if ($ETagMSIx86 -in $this.LastState.ETagMSIx86) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest (WiX x86)", 'Info')
  return
}
if ($ETagMSIx64 -in $this.LastState.ETagMSIx64) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest (WiX x64)", 'Info')
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
  $this.CurrentState.ETagMSIx86 = $this.LastState.ETagMSIx86 + $ETagMSIx86
  $this.CurrentState.ETagMSIx64 = $this.LastState.ETagMSIx64 + $ETagMSIx64

  $this.Write()
  return
}

# ETag
$this.CurrentState.ETag = @($ETag)
$this.CurrentState.ETagMSIx86 = @($ETagMSIx86)
$this.CurrentState.ETagMSIx64 = @($ETagMSIx64)

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
