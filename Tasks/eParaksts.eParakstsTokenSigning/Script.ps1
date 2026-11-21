$Prefix = 'https://www.eparaksts.lv/files/ep3/'

$Object1 = Invoke-RestMethod -Uri "${Prefix}eparaksts-token-signing-windows.xml"

# Version
$this.CurrentState.Version = $Object1.update.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Prefix $Object1.update.uri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
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
