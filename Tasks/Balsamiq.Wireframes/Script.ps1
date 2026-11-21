$Object1 = Invoke-RestMethod -Uri 'https://builds.balsamiq.com/bwd/win.jsonp' | Get-EmbeddedJson -StartsFrom 'jsoncallback(' | ConvertFrom-Json

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'inno'
  InstallerUrl  = "https://build_archives.s3.amazonaws.com/Wireframes-Windows/Balsamiq_Wireframes_$($this.CurrentState.Version)_x86_Setup.exe"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'inno'
  InstallerUrl  = "https://build_archives.s3.amazonaws.com/Wireframes-Windows/Balsamiq_Wireframes_$($this.CurrentState.Version)_x64_Setup.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.date | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://balsamiq.com/wireframes/desktop/release-notes/#win' | ConvertFrom-Html
      $ReleaseNotesNode = $Object2.SelectSingleNode("//*[@class='whats-new-entry' and contains(., 'Windows: $($this.CurrentState.Version)')]")

      if ($ReleaseNotesNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime ??= [regex]::Match($ReleaseNotesNode.InnerText, '(\d{1,2}\W+[a-zA-Z]+\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectNodes('.//hr[1]/following-sibling::node()') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) and ReleaseNotesUrl for version $($this.CurrentState.Version)", 'Warning')
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

    if ($this.Status.Contains('New') -and ($this.LastState.Version.Split('.')[0..1] -join '.') -ne ($this.CurrentState.Version.Split('.')[0..1] -join '.')) {
      $this.Log('Major or minor version number has changed, please update the old installer URLs.', 'Warning')
    }
  }
}
