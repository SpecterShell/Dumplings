$Object = Invoke-RestMethod -Uri 'https://xstudio-singer.xiaoice.com/version/update' -Headers @{
  'architecture-abi'      = 'x86_64'
  'platform-with-version' = 'Windows'
}

# Version
$Task.CurrentState.Version = $Object.latest.name

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.latest.release.url
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object.latest.release.date | ConvertTo-UtcDateTime -Id 'UTC'

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.latest.release.content | Format-Text
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
