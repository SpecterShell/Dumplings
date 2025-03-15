$Object1 = Invoke-RestMethod -Uri 'https://dl.eviware.com/version-update/readyapi-updates.xml'
$Object2 = $Object1.updateDescriptor.entry.Where({ $_.targetMediaFileId -eq '1387' }, 'First')[0]

# Version
$this.CurrentState.Version = $Object2.newVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Object1.updateDescriptor.baseUrl $Object2.fileName
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Uri3 = 'https://support.smartbear.com/readyapi/docs/en/what-s-new/version-history.html'
      $Object3 = Invoke-WebRequest -Uri $Uri3 | ConvertFrom-Html

      if ($ReleaseNotesUrlNode = $Object3.SelectSingleNode("//a[contains(text(), 'ReadyAPI $($this.CurrentState.Version)')]")) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesUrlNode.InnerText, '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})').Value | Get-Date -Format 'yyyy-MM-dd'

        # Don't add this ReleaseNotesUrl as the content may change when a new version is released
        $Object4 = Invoke-WebRequest -Uri (Join-Uri $Uri3 $ReleaseNotesUrlNode.Attributes['href'].Value) | ConvertFrom-Html

        $ReleaseNotesNodes = for ($Node = $Object4.SelectSingleNode('//section[contains(@class, "original-topic")]/div[@class="titlepage"]').NextSibling; $Node -and -not $Node.SelectSingleNode('.//div[@class="titlepage" and contains(., "See Also")]'); $Node = $Node.NextSibling) { $Node }
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
