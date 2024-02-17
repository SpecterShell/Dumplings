$this.CurrentState = $LocalStorage.WondershareUpgradeInfo['9629']

# ProductCode
$this.CurrentState.Installer[0]['ProductCode'] = "UniConverter $($this.CurrentState.Version.Split('.')[0])_is1"

# PackageName
$this.CurrentState.Locale += [ordered]@{
  Key   = 'PackageName'
  Value = "Wondershare UniConverter $($this.CurrentState.Version.Split('.')[0])"
}

$ToBeSubmitted = $true
if ($this.CurrentState.Version.Split('.')[0] -ne '14') {
  $this.Log('The PackageIdentifier needs to be updated', 'Error')
  $ToBeSubmitted = $false
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl

    # InstallerSha256
    $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Print()
    $this.Message()
  }
  ({ $_ -ge 3 -and $ToBeSubmitted }) {
    $this.Submit()
  }
}
