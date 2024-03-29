$Prefix = 'https://pcclient.download.youku.com/iku-win-release/'

$this.CurrentState = Invoke-RestMethod -Uri "${Prefix}latest.yml?noCache=$(Get-Random)" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix -Locale 'zh-CN'

# RealVersion
$this.CurrentState.RealVersion = $RealVersion = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+\.\d+\.\d+\.\d+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object1 = Invoke-RestMethod -Uri 'https://hudong.alicdn.com/api/data/v2/698d45f854c64b95a87f2a947ed4e12b.js' | Get-EmbeddedJson -StartsFrom 'cbUpdateConfig(' | ConvertFrom-Json

      $ReleaseNotesNode = $Object1.win.strategies.Where({ $_.method.targetVersion -eq $RealVersion }, 'First')
      if ($ReleaseNotesNode) {
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode[0].method.feature | ConvertFrom-Html | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
