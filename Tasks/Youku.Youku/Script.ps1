$Prefix = 'https://pcclient.download.youku.com/iku-win-release/'

$Task.CurrentState = Invoke-RestMethod -Uri "${Prefix}latest.yml?noCache=$((New-Guid).Guid.Split('-')[0])" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix -Locale 'zh-CN'

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Object = Invoke-RestMethod -Uri 'https://hudong.alicdn.com/api/data/v2/698d45f854c64b95a87f2a947ed4e12b.js' | Get-EmbeddedJson -StartsFrom 'cbUpdateConfig(' | ConvertFrom-Json

    # RealVersion
    $Task.CurrentState.RealVersion = $Object.win.strategies[-1].method.targetVersion

    try {
      if ($Object.win.strategies[-1].method.targetVersion.Contains($Task.CurrentState.Version)) {
        # ReleaseNotes (zh-CN)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object.win.strategies[-1].method.feature | ConvertFrom-Html | Get-TextContent | Format-Text
        }
      } else {
        $Task.Logging("No ReleaseNotes for version $($Task.CurrentState.Version)", 'Warning')
      }
    } catch {
      $Task.Logging($_, 'Warning')
    }

    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 }) {
    $Task.Submit()
  }
}
