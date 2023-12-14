$Object1 = Invoke-RestMethod -Uri 'https://easinote.seewo.com/com/softinfo?softCode=EasiNote5'

# Version
$Task.CurrentState.Version = $Object1.data[0].softVersion

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data[0].downloadUrl
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object1.data[0].softPublishtime | ConvertFrom-UnixTimeMilliseconds

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Object2 = (Invoke-RestMethod -Uri 'https://easinote.seewo.com/com/apis?api=GET_LOG').data | Where-Object -Property version -EQ -Value $Task.CurrentState.Version

    try {
      if ($Object2) {
        # ReleaseNotes (zh-CN)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object2.description | ConvertFrom-Html | Get-TextContent | Format-Text
        }
      } else {
        $Task.Logging("No ReleaseNotes for version $($Task.CurrentState.Version)", 'Warning')
      }
    } catch {
      $Task.Logging($_, 'Warning')
    }

    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 }) {
    $Task.Submit()
  }
}
