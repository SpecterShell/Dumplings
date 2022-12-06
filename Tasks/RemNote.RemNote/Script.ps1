$Prefix = 'https://download.remnote.io/'

$Task.CurrentState = Invoke-RestMethod -Uri "${Prefix}latest.yml" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    $Object2 = (Invoke-RestMethod -Uri 'https://gateway.hellonext.co/api/v2/changelogs' -Headers @{
        'x-organization' = 'feedback.remnote.com'
      }
    ) | Where-Object -Property title -EQ -Value $Task.CurrentState.Version

    try {
      if ($Object2) {
        # ReleaseNotes (zh-CN)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object2.description_html | ConvertFrom-Html | Get-TextContent | Format-Text
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
