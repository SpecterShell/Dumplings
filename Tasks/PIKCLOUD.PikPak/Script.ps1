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
  InstallerUrl = Get-RedirectedUrl1st -Uri 'https://api-drive.mypikpak.com/package/v1/download/official_PikPak.exe?pf=windows'
}

# ReleaseNotes (en-US)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotes'
  Value  = $Object1.values.client_version.news | Format-Text
}

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object2.values.client_version.news | Format-Text
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
