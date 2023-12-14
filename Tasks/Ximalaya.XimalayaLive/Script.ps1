$Prefix = 'https://s1.xmcdn.com/yx/xmly-live-release/last/dist/'

$Task.CurrentState = Invoke-RestMethod -Uri "${Prefix}latest.yml?noCache=$((New-Guid).Guid.Split('-')[0])" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix -Locale 'zh-CN'

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
