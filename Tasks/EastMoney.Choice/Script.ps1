$Object1 = Invoke-RestMethod -Uri 'https://innovfile.eastmoney.com/innovfile/prd/pcversionCfg.json'

# Version
$this.CurrentState.Version = $Object1.win

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = 'https://choice-app.eastmoney.com/choice/OfflinePackage/ChoiceSetup_win_x86.exe'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromNSIS

    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
