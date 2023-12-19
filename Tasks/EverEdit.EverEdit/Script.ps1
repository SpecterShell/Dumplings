$Object1 = Invoke-RestMethod -Uri 'http://update.everedit.net/checkver.php' | ConvertFrom-Ini

# Version
$Task.CurrentState.Version = $Version = $Object1.Version.Version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $InstallerUrl1 = Get-RedirectedUrl -Uri 'http://www.everedit.net/latest.php?cpu=x86'
}
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrl2 = Get-RedirectedUrl -Uri 'http://www.everedit.net/latest.php?cpu=x64'
}

$Identical = $true
if (-not $InstallerUrl1.Contains($Version.Split('.')[3]) -or -not $InstallerUrl2.Contains($Version.Split('.')[3])) {
  $Task.Logging('Distinct versions detected', 'Warning')
  $Identical = $false
}

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Object2 = (Invoke-WebRequest -Uri 'https://www.everedit.net/changelog' -Headers @{ Cookie = 'lang=en' }).Content | Get-EmbeddedJson -StartsFrom 'let rows = ' | ConvertFrom-Json

    try {
      $ReleaseNotesNode = $Object2 | Where-Object -FilterScript { $_.title.StartsWith("EverEdit ${Version}") }
      if ($ReleaseNotesNode) {
        # ReleaseTime
        $Task.CurrentState.ReleaseTime = $ReleaseNotesNode.createAt | ConvertTo-UtcDateTime -Id 'China Standard Time'

        # ReleaseNotes (en-US)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = ($ReleaseNotesNode.content | ConvertFrom-Markdown).Html | ConvertFrom-Html | Get-TextContent | Format-Text
        }
      } else {
        $Task.Logging("No ReleaseNotes (en-US) for version $($Task.CurrentState.Version)", 'Warning')
      }
    } catch {
      $Task.Logging($_, 'Warning')
    }

    $Object3 = (Invoke-WebRequest -Uri 'https://www.everedit.net/changelog' -Headers @{ Cookie = 'lang=zh_cn' }).Content | Get-EmbeddedJson -StartsFrom 'let rows = ' | ConvertFrom-Json

    try {
      $ReleaseNotesNode = $Object3 | Where-Object -FilterScript { $_.title.StartsWith("EverEdit ${Version}") }
      if ($ReleaseNotesNode) {
        # ReleaseTime
        $Task.CurrentState.ReleaseTime ??= $ReleaseNotesNode.createAt | ConvertTo-UtcDateTime -Id 'China Standard Time'

        # ReleaseNotes (zh-CN)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = ($ReleaseNotesNode.content | ConvertFrom-Markdown).Html | ConvertFrom-Html | Get-TextContent | Format-Text
        }
      } else {
        $Task.Logging("No ReleaseNotes (zh-CN) for version $($Task.CurrentState.Version)", 'Warning')
      }
    } catch {
      $Task.Logging($_, 'Warning')
    }

    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 -and $Identical }) {
    $Task.Submit()
  }
}
