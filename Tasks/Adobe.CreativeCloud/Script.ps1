$Object1 = (Invoke-RestMethod -Uri 'https://cdn-ffc.oobesaas.adobe.com/core/v1/applications?name=CreativeCloud&platform=win64').applications.application.Where({ $_.name -eq 'CreativeCloud' }, 'First')[0]

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl    = $InstallerUrl = 'https://prod-rel-ffc-ccm.oobesaas.adobe.com/adobe-ffc-external/core/v1/wam/download?sapCode=KCCC&wamFeature=nuj-live'
  InstallerSha256 = (Get-TempFile -Uri "${InstallerUrl}&t=$(Get-Date -Format 'yyyyMMdd')" | Get-FileHash -Algorithm SHA256).Hash
}

# Case 0: Force submit the manifest
if ($Global:DumplingsPreference.Contains('Force')) {
  $this.Log('Skip checking states', 'Info')

  $this.Print()
  $this.Write()
  $this.Message()
  $this.Submit()
  return
}

# Case 1: The task is newly created
if ($this.Status.Contains('New')) {
  $this.Log('New task', 'Info')

  $this.Print()
  $this.Write()
  return
}

# Case 2: The version was updated or rollbacked
switch -Regex ($this.Check()) {
  'Updated|Rollbacked' {
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
    return
  }
}

# Case 3: The hash was not updated
if ($this.CurrentState.Installer[0].InstallerSha256 -eq $this.LastState.Installer[0].InstallerSha256) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest", 'Info')
  return
}

# Case 6: The hash was updated
$this.Log('The hash was changed', 'Info')
$this.Config.IgnorePRCheck = $true
$this.Print()
$this.Write()
$this.Message()
$this.Submit()
