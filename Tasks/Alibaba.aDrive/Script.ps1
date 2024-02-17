$Object1 = Invoke-RestMethod -Uri 'https://www.aliyundrive.com/desktop/version/update.json'

$this.CurrentState = Invoke-RestMethod -Uri "$($Object1.url)/win32/ia32/latest.yml?noCache=$(Get-Random)" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Locale 'zh-CN'

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
