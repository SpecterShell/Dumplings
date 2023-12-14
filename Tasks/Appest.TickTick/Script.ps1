$Object = Invoke-WebRequest -Uri 'https://pull.ticktick.com/windows/release_note.json' | Read-ResponseContent | ConvertFrom-Json

# Version
$Task.CurrentState.Version = $Object.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = Get-RedirectedUrl -Uri 'https://www.ticktick.com/static/getApp/download?type=win'
}
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Get-RedirectedUrl -Uri 'https://www.ticktick.com/static/getApp/download?type=win64'
}

# Sometimes the installers do not match the version
if ($Task.CurrentState.Installer[0].InstallerUrl.Contains($Task.CurrentState.Version -csplit '\.' -join '')) {
  # ReleaseTime
  $Task.CurrentState.ReleaseTime = [datetime]::ParseExact($Object.release_date, 'yyyyMMdd', $null).ToString('yyyy-MM-dd')

  # ReleaseNotes (en-US)
  $Task.CurrentState.Locale += [ordered]@{
    Locale = 'en-US'
    Key    = 'ReleaseNotes'
    Value  = ($Object.data | Where-Object -Property 'lang' -EQ -Value 'en').content | Format-Text
  }
  # ReleaseNotes (zh-CN)
  $Task.CurrentState.Locale += [ordered]@{
    Locale = 'zh-CN'
    Key    = 'ReleaseNotes'
    Value  = ($Object.data | Where-Object -Property 'lang' -EQ -Value 'zh_cn').content | Format-Text
  }
} else {
  $Task.Logging('The installers do not match the version', 'Warning')

  # Version
  $Task.CurrentState.Version = [regex]::Match(
    $Task.CurrentState.Installer[0].InstallerUrl,
    '([\d\.]+)\.exe'
  ).Groups[1].Value -creplace '(?<=\d)(\d)', '.$1'
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
