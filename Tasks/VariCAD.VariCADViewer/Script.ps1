$Object1 = Invoke-RestMethod -Uri 'https://upgrade.varicad.com/upgrade/installerInfoUtf8.php?packageType=3' -UserAgent 'VariCAD_Installer 1.5'

# Version
$this.CurrentState.Version = [regex]::Match($Object1, '(?m)<version>(.+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://$([regex]::Match($Object1, '(?m)<server>(.+)').Groups[1].Value)/files/$([regex]::Match($Object1, '(?m)<filename>(.+)').Groups[1].Value)"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = 'https://www.varicad.com/en/home/products/news/'
      }

      $Object2 = Invoke-WebRequest -Uri 'https://www.varicad.com/en/home/products/news/' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//h2[contains(., '$($this.CurrentState.Version -replace '0+$', '0')')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.InnerText, '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        $ReleaseNotesUrlNode = $ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::div[@class="box3"]//a[@class="sipka"]')
        # ReleaseNotesUrl (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = [regex]::Match($ReleaseNotesUrlNode.Attributes['href'].Value, "(https?://[^'`"]+)").Groups[1].Value | ConvertTo-HtmlDecodedText
        }
        $ReleaseNotesUrlNode.Remove()

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::div[@class="box3"]') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime, ReleaseNotes (en-US) and ReleaseNotesUrl for version $($this.CurrentState.Version)", 'Warning')
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
