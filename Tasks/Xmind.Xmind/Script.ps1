$Object1 = Invoke-RestMethod -Uri 'https://www.xmind.app/xmind/update/latest-win64.yml' | ConvertFrom-Yaml

# Version
$Task.CurrentState.Version = $Object1.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.url
}

# Sometimes the installers do not match the version
if ($Task.CurrentState.Installer[0].InstallerUrl.Contains($Task.CurrentState.Version -csplit '\.' -join '')) {
  # ReleaseTime
  $Task.CurrentState.ReleaseTime = [datetime]::ParseExact($Object.release_date, 'yyyyMMdd', $null).ToString('yyyy-MM-dd')

  # ReleaseNotes (en-US)
  $Task.CurrentState.Locale += [ordered]@{
    Locale = 'en-US'
    Key    = 'ReleaseNotes'
    Value  = $Object1.'releaseNotes-en-US' | Format-Text
  }
  # ReleaseNotes (zh-CN)
  $Task.CurrentState.Locale += [ordered]@{
    Locale = 'zh-CN'
    Key    = 'ReleaseNotes'
    Value  = $Object1.'releaseNotes-zh-CN' | Format-Text
  }
} else {
  Write-Host -Object "Task $($Task.Name): The installers do not match the version" -ForegroundColor Yellow

  # Version
  $Task.CurrentState.Version = [regex]::Match(
    $Task.CurrentState.Installer[0].InstallerUrl,
    '([\d\.]+)\.exe'
  ).Groups[1].Value
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    $Object2 = Invoke-WebRequest -Uri 'https://xmind.app/desktop/release-notes/' | ConvertFrom-Html

    try {
      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//*[@id='release-notes']/div/div/div[contains(./h3/text(), '$($Task.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $Task.CurrentState.ReleaseTime = $ReleaseNotesTitleNode.SelectSingleNode('./h5').InnerText.Trim() | Get-Date -Format 'yyyy-MM-dd'
      } else {
        Write-Host -Object "Task $($Task.Name): No ReleaseTime for version $($Task.CurrentState.Version)" -ForegroundColor Yellow
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
