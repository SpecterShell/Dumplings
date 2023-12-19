$Object = Invoke-RestMethod -Uri 'https://www.aliyundrive.com/desktop/version/update.json'

$this.CurrentState = Invoke-RestMethod -Uri "$($Object.url)/win32/ia32/latest.yml?noCache=$((New-Guid).Guid.Split('-')[0])" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Locale 'zh-CN'

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
