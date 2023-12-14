$Object = (Invoke-RestMethod -Uri 'https://video.laihua.com/common/config?type=15').data.videoUpdate | ConvertFrom-Json

# Version
$Task.CurrentState.Version = $Object.versionCode

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.downloadUrl
}

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.description | Format-Text
}

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 }) {
    $Task.Submit()
  }
}
