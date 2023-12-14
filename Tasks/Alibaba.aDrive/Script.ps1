$Object = Invoke-RestMethod -Uri 'https://www.aliyundrive.com/desktop/version/update.json'

$Task.CurrentState = Invoke-RestMethod -Uri "$($Object.url)/win32/ia32/latest.yml?noCache=$((New-Guid).Guid.Split('-')[0])" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Locale 'zh-CN'

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 }) {
    $Task.Submit()
  }
}
