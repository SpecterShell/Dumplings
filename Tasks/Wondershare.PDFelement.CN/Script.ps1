$this.CurrentState = Invoke-WondershareXmlUpgradeApi -ProductId 5387 -Version '8.0.0.0' -Locale 'zh-CN'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = "https://cc-download.wondershare.cc/cbs_down/pdfelement_$($this.CurrentState.Version)_full5387.exe"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://cc-download.wondershare.cc/cbs_down/pdfelement_64bit_$($this.CurrentState.Version)_full5387.exe"
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
    if ($this.CurrentState.Version.Split('.')[0] -ne '10') {
      $this.Log('The ProductCode needs to be updated', 'Error')
    } else {
      $this.Submit()
    }
  }
}
