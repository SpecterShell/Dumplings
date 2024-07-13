$Object1 = (Invoke-RestMethod -Uri 'https://lf3-beecdn.bytetos.com/obj/ies-fe-bee/bee_prod/biz_950/bee_prod_950_bee_publish_12983.json').Where({ $Object1.key -eq 'windows' })[0]

# Version
$this.CurrentState.Version = $Object1.version -replace '^V'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.link
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
