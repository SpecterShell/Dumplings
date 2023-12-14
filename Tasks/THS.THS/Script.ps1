# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = Get-RedirectedUrl1st -Uri 'https://download.10jqka.com.cn/index/download/id/84/'
}

# Version
$Task.CurrentState.Version = [regex]::Match($InstallerUrl, 'insoft_([\d\.]+)').Groups[1].Value

if (!$InstallerUrl.Contains($Task.CurrentState.Version)) {
  throw "Task $($Task.Name): The InstallerUrl`n${InstallerUrl}`ndoesn't contain version $($Task.CurrentState.Version)"
}

$Content = (Invoke-WebRequest -Uri 'https://activity.10jqka.com.cn/acmake/cache/486.html').Content

$ReleaseNotes = @()
if ($Content -cmatch "text1:\s*'([^']+)'") {
  $ReleaseNotes += $Matches[1]
}
if ($Content -cmatch "text2:\s*'([^']+)'") {
  $ReleaseNotes += $Matches[1]
}
if ($Content -cmatch "text3:\s*'([^']+)'") {
  $ReleaseNotes += $Matches[1]
}

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $ReleaseNotes | Format-Text
}

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 }) {
    $Task.Submit()
  }
}
