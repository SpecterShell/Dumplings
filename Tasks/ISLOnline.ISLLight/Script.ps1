$Object1 = [System.Net.Http.Headers.ContentDispositionHeaderValue](Invoke-WebRequest -Uri 'https://islonline.net/users/download/ISLLight?platform=win32' -Method Head).Headers.'Content-Disposition'[0]

# Version
$this.CurrentState.Version = [regex]::Match($Object1.FileName, '(\d+(?:_\d+)+)').Groups[1].Value.Replace('_', '.')

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://islonline.net/users/download/ISLLight?platform=win32&version=$($this.CurrentState.Version)"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl = 'https://www.islonline.com/whats-new/'
      }

      $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html
      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//h4[contains(., 'ISL Light $($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseNotes (en-US)
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h3'; $Node = $Node.NextSibling) {
          if ($ReleaseNotesUrlNode = $Node.SelectSingleNode('.//a[contains(., "full release info")]')) {
            # ReleaseNotesUrl (en-US)
            $this.CurrentState.Locale += [ordered]@{
              Locale = 'en-US'
              Key    = 'ReleaseNotesUrl'
              Value  = $ReleaseNotesUrlNode.Attributes['href'].Value
            }
          } elseif (-not $Node.HasClass('alert')) {
            $Node
          }
        }
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) and ReleaseNotesUrl (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
