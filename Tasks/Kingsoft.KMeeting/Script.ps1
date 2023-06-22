$Object = Invoke-RestMethod -Uri 'https://meeting.kdocs.cn/api/v1/app/version?os=win&app=meeting&try_get_gray=true'

# Version
$Task.CurrentState.Version = $Object.data.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.data.market_url
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object.data.updated_at | ConvertFrom-UnixTimeSeconds

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.data.content | ConvertTo-OrderedList | Format-Text
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    # RealVersion
    $Task.CurrentState.RealVersion = Get-TempFile -Uri $Task.CurrentState.Installer[0].InstallerUrl | Read-ProductVersionFromExe

    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
