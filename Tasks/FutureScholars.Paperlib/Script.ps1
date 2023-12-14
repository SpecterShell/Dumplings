$Prefix = 'https://paperlib.app/distribution/electron-win/'

$Task.CurrentState = Invoke-RestMethod -Uri "${Prefix}latest.yml?noCache=$((New-Guid).Guid.Split('-')[0])" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix -Locale 'zh-CN'

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Object1 = (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/GeoffreyChen777/paperlib/master/CHANGELOG_EN.md' | ConvertFrom-Markdown).Html | ConvertFrom-Html

    try {
      $ReleaseNotesTitleNode = $Object1.SelectSingleNode("./h2[contains(@id, '$($Task.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $Task.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.InnerText, '([a-zA-Z]{3} \d{1,2} \d{4})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $ReleaseNotesNodes = @()
        for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node.Name -ne 'h2'; $Node = $Node.NextSibling) {
          $ReleaseNotesNodes += $Node
        }
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $Task.Logging("No ReleaseNotes (en-US) for version $($Task.CurrentState.Version)", 'Warning')
      }
    } catch {
      $Task.Logging($_, 'Warning')
    }

    $Object2 = (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/GeoffreyChen777/paperlib/master/CHANGELOG_CN.md' | ConvertFrom-Markdown).Html | ConvertFrom-Html

    try {
      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("./h2[contains(@id, '$($Task.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $Task.CurrentState.ReleaseTime ??= [datetime]::ParseExact(
          [regex]::Match($ReleaseNotesTitleNode.InnerText, '(\d{1,2}/\d{2} \d{4})').Groups[1].Value,
          'dd/MM yyyy',
          $null
        ).ToString('yyyy-MM-dd')

        # ReleaseNotes (zh-CN)
        $ReleaseNotesNodes = @()
        for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node.Name -ne 'h2'; $Node = $Node.NextSibling) {
          $ReleaseNotesNodes += $Node
        }
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $Task.Logging("No ReleaseNotes (zh-CN) for version $($Task.CurrentState.Version)", 'Warning')
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
