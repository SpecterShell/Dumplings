$Object1 = Invoke-RestMethod -Uri 'https://appversion.115.com/1/web/1.0/api/chrome'

# Version
$Task.CurrentState.Version = $Object1.data.win.version_code

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.win.version_url
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object1.data.win.created_time | ConvertFrom-UnixTimeSeconds

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    $Object2 = Invoke-WebRequest -Uri 'https://115.com/115/T504444.html' | ConvertFrom-Html

    try {
      # ReleaseNotesUrl (zh-CN)
      $ReleaseNotesUrl = $Object2.SelectSingleNode("//*[@id='js_content_box']/table/tbody/tr[./td[1]/p/span/text()='Windows']/td[2]/p/a[contains(./span/text(),'$($Task.CurrentState.Version)')]").Attributes['href'].Value
      $Task.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $ReleaseNotesUrl
      }
    } catch {
      Write-Host -Object "Task $($Task.Name): ${_}" -ForegroundColor Yellow
      $Task.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $null
      }
    }

    if ($ReleaseNotesUrl) {
      $Object3 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      try {
        # ReleaseNotes (zh-CN)
        $ReleaseNotesNode = $Object3.SelectNodes('//*[@id="js_content_box"]/div[2]/div/div/div/div[last()]')
        if ($ReleaseNotesNode) {
          $Task.CurrentState.Locale += [ordered]@{
            Locale = 'zh-CN'
            Key    = 'ReleaseNotes'
            Value  = ($ReleaseNotesNode | Get-TextContent) -csplit '(?m)^-+$' | Select-Object -First 1 | Format-Text
          }
        } else {
          Write-Host -Object "Task $($Task.Name): No ReleaseNotes for version $($Task.CurrentState.Version)" -ForegroundColor Yellow
        }
      } catch {
        Write-Host -Object "Task $($Task.Name): ${_}" -ForegroundColor Yellow
      }
    } else {
      Write-Host -Object "Task $($Task.Name): No ReleaseNotesUrl for version $($Task.CurrentState.Version)" -ForegroundColor Yellow
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
