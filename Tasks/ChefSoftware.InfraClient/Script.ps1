$Object1 = Invoke-RestMethod -Uri 'https://omnitruck.chef.io/stable/chef/metadata/?p=windows&pv=10.0.22000&v=latest&m=x86_64&prerelease=false&nightlies=false' -Headers @{
  Accept = 'application/json'
}

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.url
}

# Version
$this.CurrentState.Version = [regex]::Match($Object1.url, '(\d+(?:\.\d+)+-\d+)').Groups[1].Value.Replace('-', '.')

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $ReleaseNotesRaw = Invoke-RestMethod -Uri "https://packages.chef.io/release-notes/chef/$($Object1.version).md" | Convert-MarkdownToHtml | Get-TextContent
      if ($ReleaseNotesRaw -match 'Release date: ([a-zA-Z]+\W+\d{1,2}\W+20\d{2})') {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $Matches[1] | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesRaw -replace 'Release date: ([a-zA-Z]+\W+\d{1,2}\W+20\d{2})' | Format-Text
        }
      } elseif ($ReleaseNotesRaw -match '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})') {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $Matches[1] | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesRaw | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesRaw | Format-Text
        }
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
