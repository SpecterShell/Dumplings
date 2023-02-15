$Object1 = Invoke-WebRequest -Uri 'https://wubi.sogou.com/' | ConvertFrom-Html

if ($Object1.SelectSingleNode('//*[@id="bannerCon_new"]/a').Attributes['href'].Value -cmatch '.+?(/dl/gzindex/.+?/sogou_wubi_([a-zA-Z0-9]+)\.exe)') {
  # Version
  $Task.CurrentState.Version = $Matches[2]

  # Installer
  $Task.CurrentState.Installer += [ordered]@{
    InstallerUrl = "https://ime.sogoucdn.com$($Matches[1])"
  }
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = [regex]::Match($Object1.SelectSingleNode('//*[@id="bannerCon_new"]/p[2]').InnerText, '(\d{4}-\d{1,2}-\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    $Object2 = Invoke-WebRequest -Uri 'https://wubi.sogou.com/log.php' | ConvertFrom-Html

    try {
      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//*[@class='log_con']/h2[contains(text(), '$($Task.CurrentState.Version.Insert(1, '.'))')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseNotes (zh-CN)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesTitleNode.SelectNodes('./following-sibling::*') | Get-TextContent | Format-Text
        }
      } else {
        Write-Host -Object "Task $($Task.Name): No ReleaseNotes (zh-CN) for version $($Task.CurrentState.Version)" -ForegroundColor Yellow
      }
    } catch {
      Write-Host -Object "Task $($Task.Name): ${_}" -ForegroundColor Yellow
    }

    # RealVersion
    $Task.CurrentState.RealVersion = Get-TempFile -Uri $Task.CurrentState.Installer[0].InstallerUrl | Read-FileVersionFromExe

    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
