$Object1 = Invoke-RestMethod -Uri 'https://harzing.com/download/pop8.txt' | ConvertFrom-Ini

# Version
$this.CurrentState.Version = $Object1.main.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://harzing.com/download/PoP8Setup.exe'
}

# ReleaseNotesUrl
$this.CurrentState.Locale += [ordered]@{
  Key   = 'ReleaseNotesUrl'
  Value = $ReleaseNotesUrl = $Object1.main.NewsURL
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      $ReleaseNotesNode = $Object2.SelectSingleNode("//*[@id='content']/article/table/tbody/tr[contains(./td[1]/text(), '$($this.CurrentState.Version.Split('.')[0..2] -join '.')')]")
      if ($ReleaseNotesNode) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectSingleNode('./td[2]') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Write()
  }
  'Changed|Updated' {
    $this.Print()
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
