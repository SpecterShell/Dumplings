$Content = Invoke-RestMethod -Uri 'https://www.axure.com/update-check/CheckForUpdate?info=%7B%22ClientVersion%22%3A%2210.0.0.0000%22%2C%22ClientOS%22%3A%22Windows%7C64bit%22%7D'

# Version
$Build = [regex]::Match($Content, '(?m)^id=([\d]+)$').Groups[1].Value
$Task.CurrentState.Version = "10.0.0.${Build}"

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://axure.cachefly.net/versions/10-0/AxureRP-Setup-${Build}.exe"
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = [datetime]::ParseExact(
  [regex]::Match($Content, '(?m)^subtitle=(\d{1,2}/\d{1,2}/\d{4})').Groups[1].Value,
  'M/d/yyyy',
  $null
).ToString('yyyy-MM-dd')

# ReleaseNotes (en-US)
$ReleaseNotes = [regex]::Match($Content, '(?s)message=(.+)').Groups[1].Value.Split('<title>')[1] | Split-LineEndings
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotes'
  Value  = $ReleaseNotes | Select-Object -Skip 2 | Format-Text
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
