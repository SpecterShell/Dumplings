$Object = Invoke-RestMethod -Uri 'https://pc-store.lenovomm.cn/upgrade/indep/upgrade_check'

# Version
$Task.CurrentState.Version = $Object.data.versionName

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl -Uri $Object.data.downloadUrl
}

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.data.note | Format-Text
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
