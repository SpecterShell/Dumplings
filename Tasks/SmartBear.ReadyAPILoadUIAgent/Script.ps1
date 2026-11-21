# Version
$this.CurrentState.Version = $Global:DumplingsStorage.SmartBearApps.customtableitem_org_ReReplacers[0].org_ReReplacer.Where({ $_.Search -eq '{{latest-readyapi-version-title-build}}' }, 'First')[0].Replace

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://dl.eviware.com/ready-api/$($this.CurrentState.Version)/LoadUIAgent-x64-$($this.CurrentState.Version).exe"
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
