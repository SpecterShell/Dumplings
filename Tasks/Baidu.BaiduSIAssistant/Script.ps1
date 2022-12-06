$Object = Invoke-WebRequest -Uri 'https://fanyiapp.cdn.bcebos.com/tongchuan/assistant/update/latest.yml' | Read-ResponseContent | ConvertFrom-Yaml

# Version
$Task.CurrentState.Version = $Object.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.files[0].url
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = [datetime]::ParseExact(
  $Object.releaseDate,
  "ddd MMM dd yyyy HH:mm:ss 'GMT'K '(GMT'K')'",
  [cultureinfo]::GetCultureInfo('en-US')
).ToUniversalTime()

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.detail | Format-Text | ConvertTo-UnorderedList
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
