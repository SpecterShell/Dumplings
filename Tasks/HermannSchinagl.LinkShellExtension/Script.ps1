$Object = Invoke-WebRequest -Uri 'https://schinagl.priv.at/nt/hardlinkshellext/hardlinkshellext.html' | ConvertFrom-Html

# Version
$Task.CurrentState.Version = [regex]::Match(
  $Object.SelectSingleNode('/html/body/table/tr[2]/td/div/i').InnerText,
  'Version ([\d\.]+)'
).Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = "https://schinagl.priv.at/nt/hardlinkshellext/save/$($Task.CurrentState.Version.Replace('.', ''))/HardLinkShellExt_win32.exe"
}
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://schinagl.priv.at/nt/hardlinkshellext/save/$($Task.CurrentState.Version.Replace('.', ''))/HardLinkShellExt_X64.exe"
}

$ReleaseNotesTitleNode = $Object.SelectSingleNode("/html/body/table/tr[54]/td[2]/table/tr[contains(./td[2]/text()[1], '$($Task.CurrentState.Version)')]")
if ($ReleaseNotesTitleNode) {
  # ReleaseTime
  $Task.CurrentState.ReleaseTime = $ReleaseNotesTitleNode.SelectSingleNode('./td[1]/a').InnerText.Trim() | Get-Date -Format 'yyyy-MM-dd'

  # ReleaseNotes (zh-CN)
  $Task.CurrentState.Locale += [ordered]@{
    Locale = 'zh-CN'
    Key    = 'ReleaseNotes'
    Value  = $ReleaseNotesTitleNode.SelectSingleNode('./td[2]/text()[1]/following-sibling::*') | Get-TextContent | Format-Text
  }
} else {
  Write-Host -Object "Task $($Task.Name): No ReleaseTime and ReleaseNotes for version $($Task.CurrentState.Version)" -ForegroundColor Yellow
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
