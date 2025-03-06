# Version
$this.CurrentState.Version = Invoke-RestMethod -Uri 'https://account.astutegraphics.com/am/version'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl -Uri 'https://account.astutegraphics.com/am/download?os-name=Windows'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object1 = Invoke-WebRequest -Uri 'https://astutegraphics.com/support/astutemanager-updates' | ConvertFrom-Html

      $ReleaseNotesNode = $Object1.SelectSingleNode("//div[contains(@class, 'card') and contains(.//div[@class='card-header'], 'Version $($this.CurrentState.Version)')]")
      if ($ReleaseNotesNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
          [regex]::Match(
            $ReleaseNotesNode.SelectSingleNode('.//div[@class="card-header"]').InnerText,
            '([A-Za-z]+\W+\d{1,2}(?:st|nd|rd|th)\W+20\d{2})'
          ).Groups[1].Value,
          [string[]]@(
            "MMMM d'st', yyyy",
            "MMMM d'nd', yyyy",
            "MMMM d'rd', yyyy",
            "MMMM d'th', yyyy"
          ),
          (Get-Culture -Name 'en-US'),
          [System.Globalization.DateTimeStyles]::None
        ).ToString('yyyy-MM-dd')

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectNodes('.//div[@class="card-header"]/following-sibling::node()') | Get-TextContent | Format-Text
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
