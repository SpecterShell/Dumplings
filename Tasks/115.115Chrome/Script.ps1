$Object1 = Invoke-RestMethod -Uri 'https://appversion.115.com/1/web/1.0/api/chrome'

if ($Object1.data.win.version_code -ne $Object1.data.win64.version_code) {
  $this.Log("Inconsistent versions: x86: $($Object1.data.win.version_code), x64: $($Object1.data.win64.version_code)", 'Error')
  return
}

# Version
$this.CurrentState.Version = $Object1.data.win64.version_code

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.data.win.version_url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.data.win64.version_url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.data.win.created_time | ConvertFrom-UnixTimeSeconds
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://115.com/115/T504444.html' | ConvertFrom-Html

      $ReleaseNotesUrlNode = $Object2.SelectSingleNode("//*[@id='js_content_box']/table/tbody/tr[contains(./td[@rowspan='1'][1]/p//text(), '115浏览器')]/td[@rowspan='1'][2]/p//a[contains(.//text(),'$($this.CurrentState.Version)')]")
      if ($ReleaseNotesUrlNode) {
        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $ReleaseNotesUrl = $ReleaseNotesUrlNode.Attributes['href'].Value
        }

        $Object3 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

        $ReleaseNotesNode = $Object3.SelectSingleNode('//div[contains(@class, "esta-contents")]/div/div[last()]')
        if ($ReleaseNotesNode) {
          # ReleaseNotes (zh-CN)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'zh-CN'
            Key    = 'ReleaseNotes'
            Value  = (($ReleaseNotesNode | Get-TextContent) -csplit '(?m)^-+$')[0] | Format-Text
          }
        } else {
          $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
        }
      } else {
        $this.Log("No ReleaseNotesUrl and ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = 'https://115.com/115/T504444.html'
        }
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = 'https://115.com/115/T504444.html'
      }
    }

    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
