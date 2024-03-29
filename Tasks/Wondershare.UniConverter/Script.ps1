$this.CurrentState = $Global:DumplingsStorage.WondershareUpgradeInfo['9629']

# ProductCode
$this.CurrentState.Installer[0]['ProductCode'] = "UniConverter $($this.CurrentState.Version.Split('.')[0])_is1"

# PackageName
$this.CurrentState.Locale += [ordered]@{
  Key   = 'PackageName'
  Value = "Wondershare UniConverter $($this.CurrentState.Version.Split('.')[0])"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl

    # InstallerSha256
    $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    if ($this.CurrentState.Version.Split('.')[0] -ne '14') {
      $this.Log('The PackageIdentifier needs to be updated', 'Error')
    } else {
      $this.Submit()
    }
  }
}
