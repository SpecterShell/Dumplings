$Object1 = Invoke-RestMethod -Uri 'https://close.mtlab.meitu.com/api/v1/client/latest?system=1'

# Version
$Task.CurrentState.Version = $Version = $Object1.data.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = ($Object1.data.extension | ConvertFrom-Json).url
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object1.data.updated_at

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object1.data.desc | ConvertFrom-Html | Get-TextContent | Format-Text
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    $Object2 = Invoke-RestMethod -Uri 'https://api-compos.yunxiu.meitu.com/api/v1/client/article_category?with_article=1'

    try {
      $Prefix = 'https://yunxiu.meitu.com/document/daily-record'
      $ReleaseNotesUrlObject = $Object2.data.data.Where({ $_.id -eq 2 }).articles.Where({ $_.title.StartsWith("V${Version} ") })
      if ($ReleaseNotesUrlObject) {
        # ReleaseNotesUrl
        $Task.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $Prefix + '?id=' + $ReleaseNotesUrlObject.id
        }
      } else {
        Write-Host -Object "Task $($Task.Name): No ReleaseNotesUrl for version $($Task.CurrentState.Version)" -ForegroundColor Yellow
        # ReleaseNotesUrl
        $Task.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $Prefix
        }
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
