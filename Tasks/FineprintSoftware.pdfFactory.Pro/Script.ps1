$Object1 = curl -fsSLA $DumplingsInternetExplorerUserAgent 'https://fineprint.com/' | Join-String -Separator "`n" | ConvertFrom-Html
$Object2 = $Object1.SelectSingleNode('//div[@class="pdfp homeblock"]//a[contains(text(), "DOWNLOAD")]')

# Version
$this.CurrentState.Version = [regex]::Match($Object2.InnerText, 'v(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object2.Attributes['href'].Value
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = New-TempFile
    curl -fsSLA $DumplingsInternetExplorerUserAgent -o $InstallerFile $this.CurrentState.Installer[0].InstallerUrl | Out-Host

    try {
      $Object3 = curl -fsSLA $DumplingsInternetExplorerUserAgent 'https://fineprint.com/pdfp/release-notes/' | Join-String -Separator "`n" | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object3.SelectSingleNode("//div[@id='content']/h3[contains(text(), 'Version $($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.InnerText, '([a-zA-Z]+\W+\d{1,2}\W+\d{4})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h3'; $Node = $Node.NextSibling) { $Node }
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
