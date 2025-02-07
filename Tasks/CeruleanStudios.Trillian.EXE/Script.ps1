$Object1 = Invoke-WebRequest -Uri 'https://trillian.im/get/windows/'

# Version
$this.CurrentState.Version = [regex]::Match($Object1.Content, 'v(\d+(?:\.\d+){3,})').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl -Uri "https://www.trillian.im/get/windows/$($this.CurrentState.Version.Split('.')[0..1] -join '.')/"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $ReleaseNotesUrl = "https://www.trillian.im/changelog/windows/$($this.CurrentState.Version.Split('.')[0..1] -join '.')/"
      }

      $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//div[@class='changes']/div[@class='release' and contains(text(), '$($this.CurrentState.Version.Split('.')[0..1] -join '.') Build $($this.CurrentState.Version.Split('.')[3])')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.InnerText, '([a-zA-Z]+\W+\d{1,2}\W+\d{4})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and -not $Node.HasClass('release'); $Node = $Node.NextSibling) {
          if ($Node.SelectSingleNode('./div[contains(@class, "tag")]')) {
            # Move the node to the beginning
            $TagNode = $Node.PrependChild($Node.RemoveChild($Node.SelectSingleNode('./div[contains(@class, "tag")]')))
            # Add brackets around badge text
            $TagNode.InnerHtml = "[$($TagNode.InnerText)] "
            # Make the nodes inline
            $TagNode.Name = 'span'
            $Node.SelectNodes('./div[@class="title"]').ForEach({ $_.Name = 'span' })
          }
          $Node
        }
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
