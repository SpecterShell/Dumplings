$Object1 = Invoke-RestMethod -Uri 'https://desktop-config.juno.ea.com/globalConfig.json'
$Object2 = Invoke-RestMethod -Uri "$($Object1.updater.url)/autopatch/upgrade/buckets/92"
$Object3 = Invoke-RestMethod -Uri "$($Object1.updater.url)/autopatch/versions/$($Object2.recommended.version)?locale=en-US"

# Version
$this.CurrentState.Version = $Object2.recommended.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object3.installerURL
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
