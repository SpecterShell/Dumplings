$Object1 = Invoke-RestMethod -Uri 'https://www.oxygenxml.com/allVersions.xml'
$Object2 = Invoke-RestMethod -Uri ($Object1.versions.version | Sort-Object -Property { [int]$_.number } -Bottom 1 | Select-Object -ExpandProperty 'build-file')

# Version
$this.CurrentState.Version = $Object2.checkVersion.builds.currentVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://www.oxygenxml.com/Oxygen/Author/InstData$($this.CurrentState.Version)/Windows64/VM/oxygenAuthor-64bit-openjdk.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.checkVersion.builds.build[0].pubDate | Get-Date -AsUTC

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object2.checkVersion.builds.build[0].description | Where-Object -FilterScript { $_.platform -split ', ' -contains 'Windows' -and $_.product -split ', ' -contains 'Author' } | Select-Object -ExpandProperty '#text' | Join-String -Separator "`n" | ConvertFrom-Html | Get-TextContent | Format-Text
      }

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = "https://www.oxygenxml.com/xml_author/whatisnew$($this.CurrentState.Version).html"
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
