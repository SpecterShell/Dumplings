# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Get-RedirectedUrl -Uri 'https://topazlabs.com/d/tvai/latest/win/full'
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
        Value  = $ReleaseNotesUrl = 'https://community.topazlabs.com/c/video-ai/video-ai-releases/69'
      }

      $Object1 = Invoke-RestMethod -Uri "${ReleaseNotesUrl}.json"
      if ($ReleaseNotesUrlObject = $Object1.topic_list.topics.Where({ $_.title.Contains($this.CurrentState.Version -replace '(\.0+)+$') }, 'First')) {
        # ReleaseNotesUrl (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = $ReleaseNotesUrl = "https://community.topazlabs.com/t/$($ReleaseNotesUrlObject[0].slug)/$($ReleaseNotesUrlObject[0].id)"
        }

        # ReleaseTime
        $this.CurrentState.ReleaseTime = $ReleaseNotesUrlObject[0].created_at.ToUniversalTime()

        $Object2 = Invoke-RestMethod -Uri "${ReleaseNotesUrl}.json"
        $ReleaseNotesObject = $Object2.post_stream.posts[0].cooked | ConvertFrom-Html
        $ReleaseNotesObject.SelectNodes('//*[@class="lightbox-wrapper"]').ForEach({ $_.Remove() })
        $Node = $ReleaseNotesObject.ChildNodes[0]
        $ReleaseNotesNodes = for (; $Node -and $Node.Name -ne 'hr'; $Node = $Node.NextSibling) { $Node }
        $Node = $Node.SelectSingleNode('./following-sibling::hr[1]')
        $ReleaseNotesNodes += for (; $Node; $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text | Set-Clipboard
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotesUrl (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
