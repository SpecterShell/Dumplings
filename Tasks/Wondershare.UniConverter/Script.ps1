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

    $WinGetInstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    if ($this.CurrentState.Version.Split('.')[0] -ne $this.Config.WinGetIdentifier.Split('.')[-1]) {
      $this.Log('The PackageIdentifier needs to be updated', 'Error')
    } else {
      $this.Submit()
    }
  }
}
