$Prefix = 'https://cdn.wostatic.cn/dist/installers/'

$this.CurrentState = (Invoke-RestMethod -Uri "${Prefix}electron-versions.json").win | ConvertFrom-ElectronUpdater -Prefix $Prefix

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
