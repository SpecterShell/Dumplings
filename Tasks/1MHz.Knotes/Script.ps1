$Prefix = 'https://knotes2-release-cn.s3.amazonaws.com/win/'

$Task.CurrentState = Invoke-RestMethod -Uri "${Prefix}latest.yml?noCache=$((New-Guid).Guid.Split('-')[0])" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Object2 = Invoke-WebRequest -Uri 'https://help.knotesapp.com/changelog-posts/' | ConvertFrom-Html
    $Object3 = Invoke-WebRequest -Uri 'https://help.knotesapp.cn/changelog-posts/' -SkipCertificateCheck | ConvertFrom-Html

    try {
      $ReleaseNotesNode = $Object2.SelectSingleNode("/html/body/div[2]/div/article[contains(./div[1]/h2, '$($Task.CurrentState.Version)')]")
      if ($ReleaseNotesNode) {
        # ReleaseNotes (en-US)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectSingleNode('./div[2]') | Get-TextContent | Format-Text
        }
      } else {
        $Task.Logging("No ReleaseNotes (en-US) for version $($Task.CurrentState.Version)", 'Warning')
      }

      $ReleaseNotesCNNode = $Object3.SelectSingleNode("/html/body/div[2]/div/article[contains(./div[1]/h2, '$($Task.CurrentState.Version)')]")
      if ($ReleaseNotesCNNode) {
        # ReleaseNotes (zh-CN)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesCNNode.SelectNodes('./div[2]//*[self::span or self::li]') |
            ForEach-Object -Process { ($_.Name -eq 'li' ? '- ' : '') + $_.InnerText } |
            Format-Text
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
