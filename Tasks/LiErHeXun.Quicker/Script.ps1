$Object1 = Invoke-RestMethod -Uri 'https://api.getquicker.net/api/account/authenticate2' -Method Post -Body (
  @{
    UserName    = 'demo@getquicker.net'
    Password    = 'demo4321'
    SoftVersion = $Task.LastState.Version ?? '1.35.42.0'
    MachineName = [System.Environment]::MachineName
    OsVersion   = [System.Environment]::OSVersion.VersionString
    Is64Bit     = $true
  } | ConvertTo-Json -Compress
) -ContentType 'application/json; charset=utf-8'

$Object2 = Invoke-RestMethod -Uri 'https://api.getquicker.net/api/account/CheckUpdate' -Method Post -Authentication Bearer -Token (ConvertTo-SecureString -String $Object1.data.userInfo.token -AsPlainText)

# Version
$Task.CurrentState.Version = $Object2.data.fastChannelVersion

# Installer
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = Get-RedirectedUrl -Uri 'https://getquicker.net/download/item/fast_x86'
}
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Get-RedirectedUrl -Uri 'https://getquicker.net/download/item/fast_x64'
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    $Object3 = Invoke-WebRequest -Uri 'https://getquicker.net/changelog?type=Pc&fromQuicker=true' | ConvertFrom-Html

    try {
      $ReleaseNotesNode = $Object3.SelectSingleNode("//*[@id='body']/div/div/div[1]/div/div[contains(./div[1]/div/h1, '$([regex]::Match($Task.CurrentState.Version, '(\d+\.\d+\.\d+)').Groups[1].Value)')]")
      if ($ReleaseNotesNode) {
        # ReleaseTime
        $Task.CurrentState.ReleaseTime = $ReleaseNotesNode.SelectSingleNode('./div[1]/div/span').InnerText | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (zh-CN)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectSingleNode('./div[2]/div') | Get-TextContent | Format-Text
        }
      } else {
        Write-Host -Object "Task $($Task.Name): No ReleaseTime and ReleaseNotes for version $($Task.CurrentState.Version)" -ForegroundColor Yellow
      }
    } catch {
      Write-Host -Object "Task $($Task.Name): ${_}" -ForegroundColor Yellow
    }

    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
