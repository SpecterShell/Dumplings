# Version
$this.CurrentState.Version = [regex]::Match($Global:DumplingsStorage.CPUZDownloadPage.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href.Contains('-cm') } catch {} }, 'First')[0].href, '(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'en-US'
  InstallerUrl    = "https://download.cpuid.com/cpu-z/cpu-z_$($this.CurrentState.Version)-cm-en.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object1 = $Global:DumplingsStorage.CPUZDownloadPage | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object1.SelectSingleNode("//div[@id='version-history']/div[contains(.//div[@class='version'], '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
          $ReleaseNotesTitleNode.SelectSingleNode('.//div[@class="date"]').InnerText,
          [string[]]@(
            "MMM dd'st', yyyy", "MMMM dd'st', yyyy",
            "MMM dd'nd', yyyy", "MMMM dd'nd', yyyy",
            "MMM dd'rd', yyyy", "MMMM dd'rd', yyyy",
            "MMM dd'th', yyyy", "MMMM dd'th', yyyy"
          ),
          (Get-Culture -Name 'en-US'),
          [System.Globalization.DateTimeStyles]::None
        ).ToString('yyyy-MM-dd')

        # Workarounds to remove download links and their following nodes in release notes
        $ReleaseNotesTitleNode.SelectSingleNode('.//div[@class="release-content"]//div[contains(@class, "links")]').SelectNodes('.|following-sibling::*').ForEach({ $_.Remove() })

        # ReleaseNotes (en-US)
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.SelectSingleNode('.//div[@class="release-content"]').ChildNodes[0]; $Node -and -not $Node.HasClass('links'); $Node = $Node.NextSibling) { $Node }
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
