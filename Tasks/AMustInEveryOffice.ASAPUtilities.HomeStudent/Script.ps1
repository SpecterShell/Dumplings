$Object1 = Invoke-WebRequest -Uri 'https://www.asap-utilities.com/download-asap-utilities-free.php?file=1'

# Version
$this.CurrentState.Version = [regex]::Match($Object1.Content, 'ASAP Utilities (\d+(?:\.\d+){2,})').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href.Contains('server1') } catch {} }, 'First')[0].href
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = (Invoke-RestMethod -Uri 'https://www.asap-utilities.com/rss.php').Where({ $_.title.Contains($this.CurrentState.Version) }, 'First')

      if ($Object2) {
        $ReleaseNotesObject = $Object2[0].description.'#cdata-section' | ConvertFrom-Html

        # Remove download section
        $SectionTitleNode = $ReleaseNotesObject.SelectSingleNode('./h3[contains(text(), "Download Now")]')
        $Nodes = for ($Node = $SectionTitleNode.NextSibling; $Node -and $Node.Name -ne 'h3'; $Node = $Node.NextSibling) { $Node }
        $SectionTitleNode.Remove()
        $Nodes.ForEach({ $_.Remove() })

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObject | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
