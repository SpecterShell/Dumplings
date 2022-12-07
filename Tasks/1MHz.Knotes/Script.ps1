$Prefix = 'https://knotes2-release-cn.s3.amazonaws.com/win/'

$Task.CurrentState = Invoke-RestMethod -Uri "${Prefix}latest.yml?noCache=$((New-Guid).Guid.Split('-')[0])" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix

switch (Compare-State) {
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
        Write-Host -Object "Task $($Task.Name): No ReleaseNotes (en-US) for version $($Task.CurrentState.Version)" -ForegroundColor Yellow
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
        Write-Host -Object "Task $($Task.Name): No ReleaseNotes (zh-CN) for version $($Task.CurrentState.Version)" -ForegroundColor Yellow
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
