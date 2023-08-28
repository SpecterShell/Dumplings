$Object = Invoke-RestMethod -Uri 'https://hudong.alicdn.com/api/data/v2/f11f572338d74092b8d87bf32791bbc0.js' | Get-EmbeddedJson -StartsFrom '$QNPortalData=' | ConvertFrom-Json

# x86
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $InstallerUrl1 = $Object.WindowsVersion.x32
}
$Version1 = [regex]::Match($InstallerUrl1, 'qianniu_\((.+)\)').Groups[1].Value

# x64
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrl2 = $Object.WindowsVersion.x64
}
$Version2 = [regex]::Match($InstallerUrl2, 'qianniu_\((.+)\)').Groups[1].Value

if ($Version1 -ne $Version2) {
  Write-Host -Object "Task $($Task.Name): The versions are different between the architectures"
  $Task.Config.Notes = '各个架构的版本号不相同'
} else {
  $Identical = $True
}

# Version
$Task.CurrentState.Version = $Version2

# ReleaseNotes (zh-CN)
$ReleaseNotesObject = $Object.iterativeDiary.Where({ $_.end.Contains('Windows') })[0].diaryList.Where({ $_.versionTitle.Contains([regex]::Match($Task.CurrentState.Version, '(\d+\.\d+\.\d)').Groups[1].Value) })
if ($ReleaseNotesObject) {
  $Task.CurrentState.Locale += [ordered]@{
    Locale = 'zh-CN'
    Key    = 'ReleaseNotes'
    Value  = $ReleaseNotesObject[0].versionContent | ConvertFrom-Html | Get-TextContent | Format-Text
  }
} else {
  Write-Host -Object "Task $($Task.Name): No ReleaseNotes for version $($Task.CurrentState.Version)" -ForegroundColor Yellow
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 -and $Identical }) {
    New-Manifest
  }
}
