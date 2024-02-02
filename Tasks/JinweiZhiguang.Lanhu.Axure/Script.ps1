$Prefix = 'https://alistatic.lanhuapp.com/Axure/'

$this.CurrentState = Invoke-WebRequest -Uri "${Prefix}latest.yml?noCache=$(Get-Random)" | Read-ResponseContent | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix -Locale 'zh-CN'

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
