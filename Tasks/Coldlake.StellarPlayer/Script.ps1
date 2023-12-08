# Download
$Object1 = (Invoke-RestMethod -Uri 'https://api.stellarplayer.com/v1/cfg/getConfig?cfgKey=nZngW7WDWeVxm').data.cfgInfo.nZngW7WDWeVxm.cfgDetail | ConvertFrom-Json
$Version1 = [regex]::Match($Object1.filename, '(\d{14})').Groups[1].Value

# Upgrade
$Object2 = Invoke-RestMethod -Uri 'https://ab.coldlake1.com/v1/abt/matcher?arch=x64&atype=show&channel=official'
$Version2 = [regex]::Match($Object2.data, '(\d{14})').Groups[1].Value

if ((Compare-Version -ReferenceVersion $Version1 -DifferenceVersion $Version2) -gt 0) {
  # Version
  $Task.CurrentState.Version = $Version2

  # Installer
  $Task.CurrentState.Installer += [ordered]@{
    InstallerUrl = "https://player-download.coldlake1.com/player/$($Task.CurrentState.Version)/Stellar_$($Task.CurrentState.Version)_official_stable_full_x64.exe"
  }
} else {
  # Version
  $Task.CurrentState.Version = $Version1

  # Installer
  $Task.CurrentState.Installer += [ordered]@{
    InstallerUrl = $Object1.offical_http_address
  }
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    # RealVersion
    $Task.CurrentState.RealVersion = Get-TempFile -Uri $Task.CurrentState.Installer[0].InstallerUrl | Read-ProductVersionFromExe

    $Object3 = Invoke-WebRequest -Uri "https://player-update.coldlake1.com/version/gray/$($Task.CurrentState.Version)_x64.ini" | Read-ResponseContent | ConvertFrom-Ini

    try {
      # ReleaseNotes (zh-CN)
      $Task.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object3.update.info | Format-Text
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
