# x64
$Object1 = Invoke-RestMethod -Uri 'https://onemark.neuxlab.cn/updates/latest.x64.xml'
# x86
$Object2 = Invoke-RestMethod -Uri 'https://onemark.neuxlab.cn/updates/latest.xml'

# Version
$Task.CurrentState.Version = $Object1.item.version

if ($Object1.item.url -ne $Object2.item.url) {
  Write-Host -Object "Task $($Task.Name): The versions are different between the architectures"
  $Task.Config.Notes = '各个架构的版本号不相同'
}

# Installer
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object2.item.url
}
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.item.url
}

# ReleaseNotesUrl
$ReleaseNotesUrl = $Object1.item.changelog
$Task.CurrentState.Locale += [ordered]@{
  Key   = 'ReleaseNotesUrl'
  Value = $ReleaseNotesUrl
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    # RealVersion
    $Task.CurrentState.RealVersion = Get-TempFile -Uri $Task.CurrentState.Installer[0].InstallerUrl | Read-ProductVersionFromMsi

    $Object3 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

    try {
      # ReleaseNotes (zh-CN)
      $Task.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object3.SelectNodes('//*[@id="main"]/div') | Get-TextContent | Format-Text
      }
    } catch {
      Write-Host -Object "Task $($Task.Name): ${_}" -ForegroundColor Yellow
    }

    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 -and $Object1.item.url -eq $Object2.item.url }) {
    New-Manifest
  }
}
