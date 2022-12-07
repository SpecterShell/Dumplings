$Object = Invoke-RestMethod -Uri 'https://www.aliyundrive.com/desktop/version/update.json'

$Task.CurrentState = Invoke-RestMethod -Uri "$($Object.url)/win32/ia32/latest.yml?noCache=$((New-Guid).Guid.Split('-')[0])" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Locale 'zh-CN'

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
