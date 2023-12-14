$Object1 = Invoke-RestMethod -Uri 'https://www.xmind.app/xmind/update/latest-win64.yml' | ConvertFrom-Yaml

# Version
$Task.CurrentState.Version = $Object1.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.url.Replace('xmind.net', 'xmind.app')
}

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

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    # RealVersion
    $Task.CurrentState.RealVersion = Get-TempFile -Uri $Task.CurrentState.Installer[0].InstallerUrl | Read-ProductVersionFromExe

    $Object2 = Invoke-WebRequest -Uri 'https://xmind.app/desktop/release-notes/' | ConvertFrom-Html

    try {
      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//*[@id='release-notes']/div/div/div[contains(./h3/text(), '$($Task.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $Task.CurrentState.ReleaseTime = $ReleaseNotesTitleNode.SelectSingleNode('./h5').InnerText.Trim() | Get-Date -Format 'yyyy-MM-dd'
      } else {
        $Task.Logging("No ReleaseTime for version $($Task.CurrentState.Version)", 'Warning')
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
