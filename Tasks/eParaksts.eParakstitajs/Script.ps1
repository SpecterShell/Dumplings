$Object1 = Invoke-RestMethod -Uri 'https://www.eparaksts.lv/files/ep3updates/eparakstitajs3-update-win64.xml'

# Version
$this.CurrentState.Version = $Object1.update.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = "https://www.eparaksts.lv/files/ep3updates/eparakstitajs3-win32-$($this.CurrentState.Version).msi"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://www.eparaksts.lv/files/ep3updates/eparakstitajs3-win64-$($this.CurrentState.Version).msi"
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
