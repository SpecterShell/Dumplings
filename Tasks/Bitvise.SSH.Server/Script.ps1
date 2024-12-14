$Object1 = Invoke-WebRequest -Uri 'https://bitvise.com/versions/BvSshServer'
$Object2 = [System.Text.Encoding]::UTF8.GetString($Object1.Content[4..(4 + [System.Convert]::ToUInt32([System.Convert]::ToHexString($Object1.Content[0..3]), 16) - 1)]) | ConvertFrom-Xml

# Version
$this.CurrentState.Version = $Object2.versions.version.ver

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object2.versions.version.installer
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.versions.version.minupax | Get-Date -Format 'yyyy-MM-dd'

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl = $Object2.versions.version.releaseNotes
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object3 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object3.SelectSingleNode("//div[@id='content']//p[contains(., 'Changes in Bitvise SSH Server $($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and -not ($Node.Name -eq 'a' -and $Node.Attributes.Contains('id')) -and $Node.Name -ne 'p'; $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
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
