$this.CurrentState = Invoke-WondershareJsonUpgradeApi -ProductId 5793 -Version '1.0.0.0' -X86 -Locale 'en-US'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://download.wondershare.com/cbs_down/mobiletrans_$($this.CurrentState.Version)_full5793.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Write()
  }
  'Changed|Updated' {
    $this.Print()
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
