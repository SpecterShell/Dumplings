$Prefix = 'https://pdflux.com/downloads/'

$Task.CurrentState = Invoke-RestMethod -Uri "${Prefix}latest.yml" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix -Locale 'zh-CN'

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    $Object = Invoke-WebRequest -Uri 'https://pdflux.com/log/' | Read-ResponseContent | ConvertFrom-Html

    try {
      $ReleaseNotesNode = $Object.SelectSingleNode("//div[contains(./@class, 'version-item') and contains(./div[3]/h3[1]/text(), '$($Task.CurrentState.Version)')]")
      if ($ReleaseNotesNode) {
        # ReleaseNotes (zh-CN)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectSingleNode('.//*[@class="version-subtitle"]') | Get-TextContent | Format-Text
        }
      } else {
        Write-Host -Object "Task $($Task.Name): No ReleaseNotes for version $($Task.CurrentState.Version)" -ForegroundColor Yellow
      }
    } catch {
      Write-Host -Object "Task $($Task.Name): ${_}" -ForegroundColor Yellow
    }

    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
