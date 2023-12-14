$Object1 = Invoke-RestMethod -Uri 'https://appversion.115.com/1/web/1.0/api/chrome'

# Version
$Task.CurrentState.Version = $Object1.data.window_115.version_code

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.window_115.version_url
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object1.data.window_115.created_time | ConvertFrom-UnixTimeSeconds

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Object2 = Invoke-WebRequest -Uri 'https://115.com/115/T504444.html' | ConvertFrom-Html

    try {
      # ReleaseNotesUrl (zh-CN)
      $ReleaseNotesUrl = $Object2.SelectSingleNode("//*[@id='js_content_box']/table/tbody/tr[./td[@rowspan='1'][1]/p//text()='115_Windows']/td[@rowspan='1'][2]/p//a[contains(.//text(),'$($Task.CurrentState.Version)')]").Attributes['href'].Value
      $Task.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $ReleaseNotesUrl
      }
    } catch {
      $Task.Logging($_, 'Warning')
      $Task.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $null
      }
    }

    if ($ReleaseNotesUrl) {
      $Object3 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      try {
        # ReleaseNotes (zh-CN)
        $ReleaseNotesNode = $Object3.SelectSingleNode('//*[@id="js_content_box"]/div[2]/div/div/div/div[last()]')
        if ($ReleaseNotesNode) {
          $Task.CurrentState.Locale += [ordered]@{
            Locale = 'zh-CN'
            Key    = 'ReleaseNotes'
            Value  = ($ReleaseNotesNode | Get-TextContent) -csplit '(?m)^-+$' | Select-Object -First 1 | Format-Text
          }
        } else {
          $Task.Logging("No ReleaseNotes for version $($Task.CurrentState.Version)", 'Warning')
        }
      } catch {
        $Task.Logging($_, 'Warning')
      }
    } else {
      $Task.Logging("No ReleaseNotesUrl for version $($Task.CurrentState.Version)", 'Warning')
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
