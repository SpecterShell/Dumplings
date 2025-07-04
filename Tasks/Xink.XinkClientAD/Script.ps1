$InstallerUrl = 'https://downloads.xink.io/win/clientad'
$InstallerFile = Get-TempFile -Uri $InstallerUrl

# Version
$this.CurrentState.Version = $InstallerFile | Read-ProductVersionFromMsi

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl           = $InstallerUrl
  InstallerSha256        = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
  ProductCode            = $InstallerFile | Read-ProductCodeFromMsi
  AppsAndFeaturesEntries = @(
    [ordered]@{
      UpgradeCode = $InstallerFile | Read-UpgradeCodeFromMsi
    }
  )
}

Remove-Item -Path $InstallerFile -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'

# Case 0: Force submit the manifest
if ($Global:DumplingsPreference.Contains('Force')) {
  $this.Log('Skip checking states', 'Info')

  $this.Print()
  $this.Write()
  $this.Message()
  $this.Submit()
  return
}

# Case 1: The task is new
if ($this.Status.Contains('New')) {
  $this.Log('New task', 'Info')

  $this.Print()
  $this.Write()
  return
}

# Case 2: The version has changed
switch -Regex ($this.Check()) {
  'Updated|Rollbacked' {
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
    return
  }
}

# Case 3: The SHA256 is unchanged
if ($this.CurrentState.Installer[0].InstallerSha256 -eq $this.LastState.Installer[0].InstallerSha256) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest", 'Info')
  return
}

# Case 4: The SHA256 has changed
$this.Log('The SHA256 has changed', 'Info')
$this.Config.IgnorePRCheck = $true
$this.Print()
$this.Write()
$this.Message()
$this.Submit()
