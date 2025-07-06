$Object1 = Invoke-WebRequest -Uri 'https://uvnc.com/downloads/ultravnc.html'

# Version
$this.CurrentState.Version = [regex]::Match($Object1.Content, 'UltraVNC (\d+(?:\.\d+)+)').Groups[1].Value
$ShortVersion = $this.CurrentState.Version.Replace('.', '')

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = "https://uvnc.eu/download/${ShortVersion}/UltraVNC_${ShortVersion}_x86_Setup.exe"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://uvnc.eu/download/${ShortVersion}/UltraVNC_${ShortVersion}_x64_Setup.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $null
      }

      if ($ReleaseNotesUrlLink = $Object1.Links.Where({ try { $_.href.Contains('//forum.uvnc.com/viewtopic.php') } catch {} }, 'First')) {
        # ReleaseNotesUrl (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = $ReleaseNotesUrl = $ReleaseNotesUrlLink[0].href
        }

        $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

        $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//div[@class='content']/node()[contains(., 'Changelog')]/following-sibling::node()[contains(., '$($this.CurrentState.Version)')]")
        if ($ReleaseNotesTitleNode) {
          # ReleaseNotes (en-US)
          $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.InnerText -notmatch '^\s*(?:Version)?\s*\d+(?:\.\d+)+' -and -not ($Node.Name -eq 'br' -and $Node.NextSibling.Name -eq 'br'); $Node = $Node.NextSibling) { $Node }
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
          }
        } else {
          $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
