$Prefix = 'https://tarma.com/download/'
$Object1 = Invoke-RestMethod -Uri "${Prefix}tin11.txt" | ConvertFrom-Ini

# Version
$this.CurrentState.Version = $Object1.main.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Prefix $Object1.main.InstallerPath
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://tarma.com/support/im11/whatsnew.htm' | ConvertFrom-Html

      $ReleaseNotesNode = $Object2.SelectSingleNode("//table/tr[contains(./td[1], '$($this.CurrentState.Version.Split('.')[0..2] -join '.')') and contains(./td[2], '$($this.CurrentState.Version.Split('.')[3])')]")
      if ($ReleaseNotesNode) {
        $i = $ReleaseNotesNode.SelectSingleNode('./td[1]').Attributes.Contains('rowspan') ? [int]$ReleaseNotesNode.SelectSingleNode('./td[1]').Attributes['rowspan'].Value : 1
        $LineBreak = '<br/>' | ConvertFrom-Html
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesNode; $Node -and $i -gt 0; $Node = $Node.SelectSingleNode('./following-sibling::tr[1]')) { $Node.SelectSingleNode('./td[last()]'); $LineBreak; $i -= 1 }
        # ReleaseNotes (en-GB)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-GB'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-GB) for version $($this.CurrentState.Version)", 'Warning')
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
