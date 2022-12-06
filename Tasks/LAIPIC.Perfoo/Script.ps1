$Object = (Invoke-RestMethod -Uri 'https://presentment-api.laihua.com/common/config?type=120').data.perfooUpdatePC | ConvertFrom-Json

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
  Value  = $Object.description.Replace('；', "；`n") | Format-Text
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
