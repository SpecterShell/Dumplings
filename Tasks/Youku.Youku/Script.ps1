$Prefix = 'https://pcclient.download.youku.com/iku-win-release/'

$this.CurrentState = Invoke-RestMethod -Uri "${Prefix}latest.yml?noCache=$((New-Guid).Guid.Split('-')[0])" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix -Locale 'zh-CN'

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $Object = Invoke-RestMethod -Uri 'https://hudong.alicdn.com/api/data/v2/698d45f854c64b95a87f2a947ed4e12b.js' | Get-EmbeddedJson -StartsFrom 'cbUpdateConfig(' | ConvertFrom-Json

    # RealVersion
    $this.CurrentState.RealVersion = $Object.win.strategies[-1].method.targetVersion

    try {
      if ($Object.win.strategies[-1].method.targetVersion.Contains($this.CurrentState.Version)) {
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object.win.strategies[-1].method.feature | ConvertFrom-Html | Get-TextContent | Format-Text
        }
      } else {
        $this.Logging("No ReleaseNotes for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $this.Logging($_, 'Warning')
    }

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
