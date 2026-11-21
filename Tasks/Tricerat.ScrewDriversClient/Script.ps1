$Object1 = Invoke-WebRequest -Uri 'https://www.tricerat.com/client-downloads'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.Links.Where({ try { $_.href.Contains('.msi') -and $_.href.Contains('x64') } catch {} }, 'First')[0].href | Split-Uri -LeftPart 'Path'
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl = 'https://tricerat.atlassian.net/wiki/spaces/TKB/pages/1045954573/Version+7+History'
      }

      $Object1 = Invoke-WebRequest -Uri $ReleaseNotesUrl
      if ($ReleaseNotesUrlLink = $Object1.Links.Where({ try { $_.href.Contains("Version+$($this.CurrentState.Version.Split('.')[0..2] -join '.')") } catch {} }, 'First')) {
        # ReleaseNotesUrl (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = $ReleaseNotesUrl = Join-Uri $ReleaseNotesUrl $ReleaseNotesUrlLink[0].href
        }

        $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

        # Remove buttons
        $Object2.SelectNodes('//button').ForEach({ $_.Remove() })
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object2.SelectSingleNode('//div[@class="ak-renderer-document"]') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotesUrl (en-US) and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
