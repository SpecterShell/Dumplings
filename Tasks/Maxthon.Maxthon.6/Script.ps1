# International x64
$Object1 = (Invoke-RestMethod -Uri 'https://updater.maxthon.com/mx6/com/updater.json').maxthon | Where-Object -Property 'channels' -Contains -Value 'stable'
# International x86
$Object2 = (Invoke-RestMethod -Uri 'https://updater.maxthon.com/mx6/com/updater_x86.json').maxthon | Where-Object -Property 'channels' -Contains -Value 'stable'
# Chinese x64
$Object3 = (Invoke-RestMethod -Uri 'https://updater.maxthon.cn/mx6/cn/updater.json').maxthon | Where-Object -Property 'channels' -Contains -Value 'stable'
# Chinese x86
$Object4 = (Invoke-RestMethod -Uri 'https://updater.maxthon.cn/mx6/cn/updater_x86.json').maxthon | Where-Object -Property 'channels' -Contains -Value 'stable'

if ((@($Object1, $Object2, $Object3, $Object4) | Sort-Object -Property 'version' -Unique).Length -gt 1) {
  Write-Host -Object "Task $($Task.Name): The versions are different between editions and/or architectures" -ForegroundColor Yellow
  $Task.Config.Notes = '各个版本和/或架构的版本号不相同'
}

# Version
$Task.CurrentState.Version = $Object1.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object2.url
}
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.url
}
$Task.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  Architecture    = 'x86'
  InstallerUrl    = $Object4.url
}
$Task.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  Architecture    = 'x64'
  InstallerUrl    = $Object3.url
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    $Object5 = Invoke-WebRequest -Uri 'https://www.maxthon.com/mx6/changelog/' | ConvertFrom-Html
    $Object6 = Invoke-WebRequest -Uri 'https://www.maxthon.cn/mx6/changelog/' | ConvertFrom-Html

    try {
      $ReleaseNotesTitleNode1 = $Object5.SelectSingleNode("//*[@id='app']/div[1]/h2[./text()='$($Task.CurrentState.Version)']")
      if ($ReleaseNotesTitleNode1) {
        # ReleaseTime
        $Task.CurrentState.ReleaseTime = [regex]::Match(
          $ReleaseNotesTitleNode1.SelectSingleNode('./time').InnerText,
          '(\d{4}-\d{1,2}-\d{1,2})'
        ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesTitleNode1.SelectSingleNode('./following-sibling::p[1]') | Get-TextContent | Format-Text
        }
      } else {
        Write-Host -Object "Task $($Task.Name): No ReleaseTime and ReleaseNotes (en-US) for version $($Task.CurrentState.Version)" -ForegroundColor Yellow
      }

      $ReleaseNotesTitleNode2 = $Object6.SelectSingleNode("//*[@id='app']/div[1]/h2[./text()='$($Task.CurrentState.Version)']")
      if ($ReleaseNotesTitleNode2) {
        # ReleaseTime
        $Task.CurrentState.ReleaseTime ??= [regex]::Match(
          $ReleaseNotesTitleNode2.SelectSingleNode('./time').InnerText,
          '(\d{4}-\d{1,2}-\d{1,2})'
        ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (zh-CN)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesTitleNode2.SelectSingleNode('./following-sibling::p[1]') | Get-TextContent | Format-Text
        }
      } else {
        Write-Host -Object "Task $($Task.Name): No ReleaseNotes (zh-CN) for version $($Task.CurrentState.Version)" -ForegroundColor Yellow
      }
    } catch {
      Write-Host -Object "Task $($Task.Name): ${_}" -ForegroundColor Yellow
    }

    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 -and (@($Object1, $Object2, $Object3, $Object4) | Sort-Object -Property 'version' -Unique).Length -eq 1 }) {
    New-Manifest
  }
}
