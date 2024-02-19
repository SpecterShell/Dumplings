$Object1 = Invoke-RestMethod -Uri 'https://www.aliyundrive.com/desktop/version/update.json'

$this.CurrentState = Invoke-RestMethod -Uri "$($Object1.url)/win32/ia32/latest.yml?noCache=$(Get-Random)" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Locale 'zh-CN'

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
