$Object = Invoke-RestMethod -Uri 'https://publish.u-tools.cn/version2/newest-version.json'

if ($Object1.win32.x64 -ne $Object1.win32.ia32) {
  Write-Host -Object "Task $($Task.Name): The versions are different between the architectures"
  $Task.Config.Notes = '各个架构的版本号不相同'
}

# Version
$Task.CurrentState.Version = $Object.win32.x64

# Installer
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = "https://res.u-tools.cn/version2/uTools-$($Task.CurrentState.Version)-ia32.exe"
}
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://res.u-tools.cn/version2/uTools-$($Task.CurrentState.Version).exe"
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    # ReleaseNotesUrl
    $ReleaseNotesUrl = Get-RedirectedUrl -Uri "https://open.u-tools.cn/redirect?target=update_description&version=$($Task.CurrentState.Version)"
    $Task.CurrentState.Locale += [ordered]@{
      Key   = 'ReleaseNotesUrl'
      Value = $ReleaseNotesUrl
    }

    $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

    try {
      if ($Object2.SelectSingleNode('/html/body/h2[1]').InnerText.Contains($Task.CurrentState.Version)) {
        if ($Object2.SelectSingleNode('/html/body/h2[2]')) {
          # ReleaseNotes (zh-CN)
          $Task.CurrentState.Locale += [ordered]@{
            Locale = 'zh-CN'
            Key    = 'ReleaseNotes'
            Value  = $Object2.SelectNodes('/html/body/p[1]/following-sibling::node()[count(.|/html/body/h2[2]/preceding-sibling::node())=count(/html/body/h2[2]/preceding-sibling::node())]') | Get-TextContent | Format-Text
          }
        } else {
          # ReleaseNotes (zh-CN)
          $Task.CurrentState.Locale += [ordered]@{
            Locale = 'zh-CN'
            Key    = 'ReleaseNotes'
            Value  = $Object2.SelectNodes('/html/body/p[1]/following-sibling::*') | Get-TextContent | Format-Text
          }
        }
      } else {
        Write-Host -Object "Task $($Task.Name): No ReleaseNotes for version $($Task.CurrentState.Version)" -ForegroundColor Yellow
      }
    } catch {
      Write-Host -Object "Task $($Task.Name): ${_}" -ForegroundColor Yellow
    }

    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 -and $Object1.win32.x64 -eq $Object1.win32.ia32 }) {
    New-Manifest
  }
}
