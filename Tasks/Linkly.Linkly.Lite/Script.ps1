$Object1 = $Global:DumplingsStorage.LinklySoftwarePageObject.SelectSingleNode('//div[./h3[@class="mb-base" and contains(., "Lite Installer")]]')

# Version
$this.CurrentState.Version = [regex]::Match($Object1.SelectSingleNode('./h3[@class="mb-base" and contains(., "Lite Installer")]').InnerText, '(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'inno'
  InstallerUrl  = $Object1.SelectSingleNode('.//a[contains(@href, ".exe") and (contains(.//u, "Download") or (contains(@class, "border-b") and contains(., "Download")))]').Attributes['href'].Value.Trim() -replace '/latest/', "/$($this.CurrentState.Version)/" | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $null
      }

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl = $Global:DumplingsStorage.LinklySoftwarePageObject.SelectSingleNode('//div[./h3[@class="mb-base" and contains(., "In-store Software")]]//a[(contains(.//u, "Release Notes") or (@class="border-b" and contains(., "Release Notes")))]').Attributes['href'].Value
      }

      # ReleaseNotes (en-US)
      $ReleaseNotesDocument = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html
      $ReleaseNotesTitleNode = $ReleaseNotesDocument.SelectNodes("//article//*[(self::h1 or self::h2 or self::h3 or self::h4) and contains(., 'Release')]")[-1]
      if ($ReleaseNotesTitleNode) {
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesTitleNode.SelectNodes('./following-sibling::node()') | Get-TextContent | Format-Text
        }
      } else {
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesTitleNode.SelectSingleNode('.//article') | Get-TextContent | Format-Text
        }
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
