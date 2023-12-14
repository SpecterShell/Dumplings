$Prefix = 'https://oss-arena.5eplay.com/client/'

$Task.CurrentState = Invoke-RestMethod -Uri "${Prefix}latest.yml?noCache=$((New-Guid).Guid.Split('-')[0])" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix -Locale 'en-US'

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Object1 = Invoke-RestMethod -Uri 'https://api-client-arena.5eplay.com/api/home'

    try {
      # ReleaseNotes (zh-CN)
      if ($Task.CurrentState.Version -eq $Object1.data.login_version_note.version) {
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object1.data.login_version_note.content.ForEach({ $_.category_name + "`n" + $_.list.ForEach({ $_.title + "`n" + $_.content }) -join "`n" }) -join "`n`n" | Format-Text
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
