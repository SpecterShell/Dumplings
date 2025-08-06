# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl -Uri 'https://topazlabs.com/d/photo/latest/win/full'
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
        Value  = 'https://community.topazlabs.com/c/photo-ai/photo-ai-releases/85'
      }

      $Object1 = Invoke-RestMethod -Uri 'https://community.topazlabs.com/c/photo-ai/photo-ai-releases/85.json'
      if ($ReleaseNotesUrlObject = $Object1.topic_list.topics.Where({ $_.title.Contains($this.CurrentState.Version) }, 'First')) {
        # ReleaseNotesUrl (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = "https://community.topazlabs.com/t/$($ReleaseNotesUrlObject[0].slug)/$($ReleaseNotesUrlObject[0].id)"
        }

        # ReleaseTime
        $this.CurrentState.ReleaseTime = $ReleaseNotesUrlObject[0].created_at.ToUniversalTime()

        $Object2 = Invoke-RestMethod -Uri "https://community.topazlabs.com/t/$($ReleaseNotesUrlObject[0].slug)/$($ReleaseNotesUrlObject[0].id).json"
        $ReleaseNotesObject = $Object2.post_stream.posts[0].cooked | ConvertFrom-Html
        $Node = $ReleaseNotesObject.ChildNodes[0]
        $ReleaseNotesNodes = for (; $Node -and $Node.Name -ne 'hr'; $Node = $Node.NextSibling) { $Node }
        if ($Node = $Node.SelectSingleNode('./following-sibling::h2[contains(text(), "Changelog")]')) {
          $ReleaseNotesNodes += for (; $Node -and $Node.Name -ne 'hr'; $Node = $Node.NextSibling) { $Node }
        }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
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
