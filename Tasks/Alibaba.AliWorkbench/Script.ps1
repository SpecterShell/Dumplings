$Object = Invoke-RestMethod -Uri 'https://hudong.alicdn.com/api/data/v2/f11f572338d74092b8d87bf32791bbc0.js' | Get-EmbeddedJson -StartsFrom '$QNPortalData=' | ConvertFrom-Json

# Installer
$InstallerUrl = $Object.Windows
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl
}

# Version
$Task.CurrentState.Version = [regex]::Match($InstallerUrl, '\((.+)\)\.exe').Groups[1].Value

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
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
