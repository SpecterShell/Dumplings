$Object1 = Invoke-RestMethod -Uri 'https://www.gpsoft.com.au/endpoints/curVersion.php'

# Version
$this.CurrentState.Version = $Object1.display

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl -Uri "https://www.gpsoft.com.au/endpoints/download.php?new=$($this.CurrentState.Version)"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $null
      }

      $Object2 = Invoke-RestMethod -Uri 'https://resource.dopus.com/c/new-releases/28.json'

      if ($ReleaseNotesUrlObject = $Object2.topic_list.topics.Where({ $_.title.Contains($this.CurrentState.Version) }, 'First')) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $ReleaseNotesUrlObject[0].created_at.ToUniversalTime()

        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = "https://resource.dopus.com/t/$($ReleaseNotesUrlObject[0].slug)/$($ReleaseNotesUrlObject[0].id)"
        }

        $Object3 = Invoke-RestMethod -Uri "https://resource.dopus.com/t/$($ReleaseNotesUrlObject[0].slug)/$($ReleaseNotesUrlObject[0].id).json"
        $ReleaseNotesObject = $Object3.post_stream.posts[0].cooked | ConvertFrom-Html

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObject.SelectNodes('/h3[1]|/h3[1]/following-sibling::node()') | Get-TextContent | Format-Text
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
