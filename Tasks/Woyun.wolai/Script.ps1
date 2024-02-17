$Prefix = 'https://cdn.wostatic.cn/dist/installers/'

$this.CurrentState = (Invoke-RestMethod -Uri "${Prefix}electron-versions.json").win | ConvertFrom-ElectronUpdater -Prefix $Prefix

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Print()
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
