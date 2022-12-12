# en-US
$Object1 = Invoke-RestMethod -Uri 'https://config.mypikpak.com/config/v1/client_version' -Method Post -Body (
  @{
    data   = @{
      language = 'en-US'
    }
    client = 'windows'
  } | ConvertTo-Json -Compress
)
# zh-CN
$Object2 = Invoke-RestMethod -Uri 'https://config.mypikpak.com/config/v1/client_version' -Method Post -Body (
  @{
    data   = @{
      language = 'zh-CN'
    }
    client = 'windows'
  } | ConvertTo-Json -Compress
)

# Version
$Task.CurrentState.Version = $Object1.values.client_version.newVersionName

# RealVersion
$Task.CurrentState.RealVersion = [regex]::Match($Task.CurrentState.Version, '(\d+\.\d+\.\d+)').Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.values.client_version.downloadURL
}

# ReleaseNotes (en-US)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotes'
  Value  = $Object1.values.client_version.news | Select-Object -Skip 1 | Format-Text
}

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object2.values.client_version.news | Select-Object -Skip 1 | Format-Text
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
