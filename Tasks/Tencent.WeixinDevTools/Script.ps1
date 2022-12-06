$Object = Invoke-WebRequest -Uri 'https://servicewechat.com/wxa-dev-logic/checkupdate?force=1' | Read-ResponseContent | ConvertFrom-Json

# Version
$Version = $Object.update_version.ToString()
$Task.CurrentState.Version = $Version.SubString(0, 1) + '.' + $Version.SubString(1, 2) + '.' + $Version.SubString(3)

# Installer
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = Get-RedirectedUrl -Uri "https://servicewechat.com/wxa-dev-logic/download_redirect?os=win&type=ia32&download_version=$($Object.update_version)&version_type=1&pack_type=0"
}
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Get-RedirectedUrl -Uri "https://servicewechat.com/wxa-dev-logic/download_redirect?os=win&type=x64&download_version=$($Object.update_version)&version_type=1&pack_type=0"
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = [datetime]::ParseExact($Version.SubString(3, 6), 'yyMMdd', $null).ToString('yyyy-MM-dd')

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.changelog_desc | Format-Text
}

# ReleaseNotesUrl (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key   = 'ReleaseNotesUrl'
  Value = $Object.changelog_url
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
