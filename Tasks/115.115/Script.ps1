$Object1 = Invoke-RestMethod -Uri 'https://appversion.115.com/1/web/1.0/api/chrome'

# Version
$this.CurrentState.Version = $Object1.data.window_115.version_code

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.window_115.version_url
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.data.window_115.created_time | ConvertFrom-UnixTimeSeconds

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $Object2 = Invoke-WebRequest -Uri 'https://115.com/115/T504444.html' | ConvertFrom-Html

    try {
      # ReleaseNotesUrl (zh-CN)
      $ReleaseNotesUrl = $Object2.SelectSingleNode("//*[@id='js_content_box']/table/tbody/tr[./td[@rowspan='1'][1]/p//text()='115_Windows']/td[@rowspan='1'][2]/p//a[contains(.//text(),'$($this.CurrentState.Version)')]").Attributes['href'].Value
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $ReleaseNotesUrl
      }
    } catch {
      $this.Logging($_, 'Warning')
      $this.CurrentState.Locale += [ordered]@{
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
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'zh-CN'
            Key    = 'ReleaseNotes'
            Value  = ($ReleaseNotesNode | Get-TextContent) -csplit '(?m)^-+$' | Select-Object -First 1 | Format-Text
          }
        } else {
          $this.Logging("No ReleaseNotes for version $($this.CurrentState.Version)", 'Warning')
        }
      } catch {
        $this.Logging($_, 'Warning')
      }
    } else {
      $this.Logging("No ReleaseNotesUrl for version $($this.CurrentState.Version)", 'Warning')
    }

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
