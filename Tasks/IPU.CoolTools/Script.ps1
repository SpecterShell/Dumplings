$Object1 = Invoke-WebRequest -Uri 'https://www.ipu.dk/refrigeration-software/cool-tools'
$InstallerLink = $Object1.Links.Where({ try { $_.href.EndsWith('.exe') } catch {} }, 'First')[0]

# Version
$this.CurrentState.Version = [regex]::Match($InstallerLink.outerHTML, '(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerLink.href
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = $Object1 | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//p[contains(text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.InnerText, '(20\d{2}/\d{1,2}/\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.InnerText -notmatch 'v\d+(?:\.\d+)+'; $Node = $Node.NextSibling) { $Node }
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
