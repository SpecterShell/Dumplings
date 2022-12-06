$Prefix = 'https://cos5.cloud.tencent.com/cosbrowser/'

$Task.CurrentState = Invoke-WebRequest -Uri "${Prefix}latest.yml" | Read-ResponseContent | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix -Locale 'zh-CN'

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
