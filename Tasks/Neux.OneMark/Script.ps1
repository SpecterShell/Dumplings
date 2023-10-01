# International x64
$Object1 = Invoke-RestMethod -Uri 'https://onemark.neux.studio/updates/latest.x64.xml'
# International x86
$Object2 = Invoke-RestMethod -Uri 'https://onemark.neux.studio/updates/latest.xml'
# Chinese x64
$Object3 = Invoke-RestMethod -Uri 'https://onemark.neuxlab.cn/updates/latest.x64.xml'
# Chinese x86
$Object4 = Invoke-RestMethod -Uri 'https://onemark.neuxlab.cn/updates/latest.xml'

if ((@($Object1, $Object2, $Object3, $Object4) | Sort-Object -Property { $_.item.version } -Unique).Length -gt 1) {
  Write-Host -Object "Task $($Task.Name): Distinct versions detected" -ForegroundColor Yellow
  $Task.Config.Notes = '检测到不同的版本'
}

# Version
$Task.CurrentState.Version = $Object1.item.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object2.item.url
}
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.item.url
}
$Task.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  Architecture    = 'x86'
  InstallerUrl    = $Object4.item.url
}
$Task.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  Architecture    = 'x64'
  InstallerUrl    = $Object3.item.url
}

# ReleaseNotesUrl
$Task.CurrentState.Locale += [ordered]@{
  Key   = 'ReleaseNotesUrl'
  Value = $ReleaseNotesUrl1 = $Object1.item.changelog
}
# ReleaseNotesUrl (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotesUrl'
  Value  = $ReleaseNotesUrl2 = $Object3.item.changelog
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    # RealVersion
    $Task.CurrentState.RealVersion = Get-TempFile -Uri $Task.CurrentState.Installer[0].InstallerUrl | Read-ProductVersionFromMsi

    $Object5 = Invoke-WebRequest -Uri $ReleaseNotesUrl1 | ConvertFrom-Html

    try {
      # ReleaseNotes (en-US)
      $Task.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object5.SelectNodes('//*[@id="main"]/div') | Get-TextContent | Format-Text
      }
    } catch {
      Write-Host -Object "Task $($Task.Name): ${_}" -ForegroundColor Yellow
    }

    $Object6 = Invoke-WebRequest -Uri $ReleaseNotesUrl2 | ConvertFrom-Html

    try {
      # ReleaseNotes (zh-CN)
      $Task.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object6.SelectNodes('//*[@id="main"]/div') | Get-TextContent | Format-Text
      }
    } catch {
      Write-Host -Object "Task $($Task.Name): ${_}" -ForegroundColor Yellow
    }

    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 -and (@($Object1, $Object2, $Object3, $Object4) | Sort-Object -Property { $_.item.version } -Unique).Length -eq 1 }) {
    New-Manifest
  }
}
