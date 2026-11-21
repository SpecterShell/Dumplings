$Object1 = Invoke-WebRequest -Uri 'https://technelysium.com.au/wp/chromaspro/'
$Link = $Object1.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.outerHTML -match '\d+(?:\.\d+){2,}' -and $_.outerHTML.Contains('Pro') } catch {} }, 'First')[0]

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Link.href
}

# Version
$this.CurrentState.Version = [regex]::Match($Link.outerHTML, '(\d+(?:\.\d+){2,})').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://technelysium.com.au/wp/chromaspro-version-history/' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//div[@class='entry-content']//p[contains(text(), 'Version $($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = @($ReleaseNotesTitleNode)
        $ReleaseNotesNodes += for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.InnerText -notmatch 'Version (\d+(?:\.\d+)+)'; $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes for version $($this.CurrentState.Version)", 'Warning')
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
