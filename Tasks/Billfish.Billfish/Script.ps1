# x64
$Object1 = Invoke-RestMethod -Uri 'https://front-gw.aunapi.com/applicationService/installer/getAppVersion?appId=10301011&versionCode=0.0.0.0&packageSystemSupport=2'
# x86
$Object2 = Invoke-RestMethod -Uri 'https://front-gw.aunapi.com/applicationService/installer/getAppVersion?appId=10301011&versionCode=0.0.0.0&packageSystemSupport=1'

# Version
$Task.CurrentState.Version = $Object1.data.versionCode

if ($Object1.data.versionCode -ne $Object2.data.versionCode) {
  Write-Host -Object "Task $($Task.Name): Distinct versions detected" -ForegroundColor Yellow
  $Task.Config.Notes = '检测到不同的版本'
}

# Installer
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object2.data.downloadUrl
}
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.data.downloadUrl
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object1.data.createTime | Get-Date | ConvertTo-UtcDateTime -Id 'China Standard Time'

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    $Object3 = Invoke-WebRequest -Uri 'https://www.billfish.cn/help/gengxinrizhi' | ConvertFrom-Html

    try {
      $ReleaseNotesTitleNode = $Object3.SelectSingleNode("//div[starts-with(@class, 'catalog_catalogContent')]/h2[contains(text(), '$($Task.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseNotes (zh-CN)
        $ReleaseNotesNodes = @()
        for ($Node = $ReleaseNotesTitleNode.NextSibling.NextSibling; $Node.Name -ne 'hr'; $Node = $Node.NextSibling) {
          $ReleaseNotesNodes += $Node
        }
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
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
  ({ $_ -ge 3 -and $Object1.data.versionCode -eq $Object2.data.versionCode }) {
    New-Manifest
  }
}
