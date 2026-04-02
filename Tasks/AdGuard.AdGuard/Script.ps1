$Object1 = Invoke-RestMethod -Uri 'https://api.adguard.org/api/2.0/checkupdate.html?app_id=64dbc91754f34b0ebcc6eecadf83eb81&channel=Release&appname=adguard_ru&version=7.0.0.0&force=1&os_version=10.0.22000.0'

# Version
$this.CurrentState.Version = $Object1.response.version.'#cdata-section'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.response.'update-url'.'#cdata-section'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl = $Object1.response.'more-info-url'.'#cdata-section'
      }

      $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      $ReleaseNotesNode = $Object2.SelectSingleNode("//div[@class='feed__item' and contains(.//div[@class='feed__title'], '$($this.CurrentState.Version.Split('.')[0..1] -join '.')')]")
      if ($ReleaseNotesNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesNode.SelectSingleNode('.//div[@class="feed__release"]').InnerText, '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectSingleNode('.//div[@class="feed__version"]') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
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
