$Prefix = 'https://www.visual-3d.com/software/downloadvisual.aspx'
$Object1 = Invoke-WebRequest -Uri $Prefix | ConvertFrom-Html

# Version
$this.CurrentState.Version = [regex]::Match($Object1.OuterHtml, 'Release:\s+(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl -Uri (Join-Uri $Prefix $Object1.SelectSingleNode('//a[contains(@onclick, "Download")]').Attributes['href'].Value)
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.visual-3d.com/Support/ReadMe.aspx' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//b[contains(text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
          [regex]::Match($ReleaseNotesTitleNode.InnerText, '(\d{1,2}/\d{1,2}/\d{2})').Groups[1].Value,
          'MM/dd/yy',
          $null
        ).ToString('yyyy-MM-dd')

        # Remove "Introduction" and "User Guide" links
        $Object2.SelectNodes('//li[contains(a, "Introduction") or contains(a, "User Guide")]').ForEach({ $_.Remove() })

        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'b'; $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (en-US)
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
