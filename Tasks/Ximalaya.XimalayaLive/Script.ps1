$Prefix = 'https://s1.xmcdn.com/yx/xmly-live-release/last/dist/'

$Task.CurrentState = Invoke-RestMethod -Uri "${Prefix}latest.yml" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix -Locale 'zh-CN'

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
