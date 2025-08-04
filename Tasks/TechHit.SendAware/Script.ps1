function Read-Installer {
  $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
  # Version
  $this.CurrentState.Version = $InstallerFile | Read-ProductVersionFromExe
  # InstallerSha256
  $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
  Remove-Item -Path $InstallerFile -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
}

$Prefix = 'https://www.techhit.com/SendAware/download.html'
$Object1 = Invoke-WebRequest -Uri $Prefix

# scope
$this.CurrentState.Installer += $InstallerUser = [ordered]@{
  Scope        = 'user'
  InstallerUrl = Join-Uri $Prefix $Object1.Links.Where({ try { $_.href.EndsWith('.exe') -and -not $_.href.Contains('admin') } catch {} }, 'First')[0].href
}
$Object2 = Invoke-WebRequest -Uri $InstallerUser.InstallerUrl -Method Head
$ETag = $Object2.Headers.ETag[0]

# machine
$this.CurrentState.Installer += $InstallerMachine = [ordered]@{
  Scope        = 'machine'
  InstallerUrl = Join-Uri $Prefix $Object1.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href.Contains('admin') } catch {} }, 'First')[0].href
}
$Object3 = Invoke-WebRequest -Uri $InstallerMachine.InstallerUrl -Method Head
$ETagMachine = $Object3.Headers.ETag[0]

# Case 0: Force submit the manifest
if ($Global:DumplingsPreference.Contains('Force')) {
  $this.Log('Skip checking states', 'Info')

  # ETag
  $this.CurrentState.ETag = @($ETag)
  $this.CurrentState.ETagMachine = @($ETagMachine)

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
  $this.CurrentState.ETagMachine = @($ETagMachine)

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
if ($ETagMachine -in $this.LastState.ETagMachine) {
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
  $this.CurrentState.ETagMachine = $this.LastState.ETagMachine + $ETagMachine

  $this.Write()
  return
}

# ETag
$this.CurrentState.ETag = @($ETag)
$this.CurrentState.ETagMachine = @($ETagMachine)

switch -Regex ($this.Check()) {
  # Case 6: The ETag, the SHA256 and the version have changed
  'Updated|Rollbacked' {
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
  # Case 5: The ETag and the SHA256 have changed, but the version is not
  default {
    $this.Log('The ETag and the SHA256 have changed, but the version is not', 'Info')
    $this.Config.IgnorePRCheck = $true
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
}
