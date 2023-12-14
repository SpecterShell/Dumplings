$Prefix = 'https://download.remnote.io/'

$Task.CurrentState = Invoke-RestMethod -Uri "${Prefix}latest.yml?noCache=$((New-Guid).Guid.Split('-')[0])" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix

switch ($Task.Check()) {
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
