# $Prefix = 'https://www.webdrive.com/cdnsoftware/'
# $Prefix = 'https://southrivertech.com/cdnsoftware/'
# $Prefix = 'https://srtcdn-gnfvdeh6hbf2g6bb.z01.azurefd.net/software/nextgen/webdrive/'
$Prefix = 'https://srtcdnstorage.blob.core.windows.net/software/nextgen/webdrive/'

$Object1 = Invoke-RestMethod -Uri "${Prefix}latest.yml" | ConvertFrom-Yaml

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Prefix $Object1.files[0].url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.releaseDate | Get-Date -AsUTC

      $ReleaseNotes = $Object1.releaseNotes.Split('|')
      $ReleaseNotesObject = $ReleaseNotes[$ReleaseNotes.IndexOf('en') + 1] | ConvertFrom-Html
      $ReleaseNotesTitleNode = $ReleaseNotesObject.SelectSingleNode("//h6[contains(text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h6'; $Node = $Node.NextSibling) { $Node }
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
