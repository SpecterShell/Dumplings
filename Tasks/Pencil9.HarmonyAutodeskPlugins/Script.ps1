$Prefix = 'https://www.pencil9.com/harmony-download.html'
$Object1 = Invoke-WebRequest -Uri $Prefix

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Prefix $Object1.Links.Where({ try { $_.href -match 'HarmonyAutodeskPlugins_(\d+(_\d+)+)\.msi$' } catch {} }, 'First')[0].href
}

# Version
$this.CurrentState.Version = $Matches[1] -replace '_', '.'

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = $Object1 | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//div[contains(@class, 'panel-default') and contains(./div[contains(@class, 'panel-heading')], 'Release Notes')]//b[contains(., '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseNotes (en-US)
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and -not ($Node.Name -eq 'b' -and $Node.InnerText -match '\d+(\.\d+)+'); $Node = $Node.NextSibling) {
          if ($Node.InnerText -match '([a-zA-Z]+\W+\d{1,2}[a-zA-Z]+\W+20\d{2})') {
            # ReleaseTime
            $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
              $Matches[1],
              [string[]]@(
                "MMM d'st' yyyy",
                "MMM d'nd' yyyy",
                "MMM d'rd' yyyy",
                "MMM d'th' yyyy"
              ),
              (Get-Culture -Name 'en-US'),
              [System.Globalization.DateTimeStyles]::None
            ).ToString('yyyy-MM-dd')
          } elseif ($Node.Name -eq 'ul') {
            $Node
          }
        }
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
