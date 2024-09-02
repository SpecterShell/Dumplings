$this.CurrentState = $Global:DumplingsStorage.WondershareUpgradeInfo['14204']

# ProductCode
$this.CurrentState.Installer[0]['ProductCode'] = "UniConverter $($this.CurrentState.Version.Split('.')[0])_is1"

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # PackageName
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'PackageName'
        Value = "Wondershare UniConverter $($this.CurrentState.Version.Split('.')[0])"
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

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
    if ($this.CurrentState.Version.Split('.')[0] -ne '15') {
      $this.Log('The PackageIdentifier needs to be updated', 'Error')
    } else {
      $this.Submit()
    }
  }
}
