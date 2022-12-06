$Prefix = 'https://dldir1.qq.com/arthub/desktop/versions/'

$Task.CurrentState = Invoke-RestMethod -Uri "${Prefix}latest-win32.yml" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix -Locale 'zh-CN'

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
