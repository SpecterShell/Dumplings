$Object1 = Invoke-WebRequest -Uri 'https://www.ipu.dk/refrigeration-software/pack-calculation-pro'
$InstallerLink = $Object1.Links.Where({ try { $_.href.EndsWith('.exe') } catch {} }, 'First')[0]

# Version
$this.CurrentState.Version = [regex]::Match($InstallerLink.outerHTML, '(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerLink.href
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = $Object1 | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//section[contains(./div/div[2], 'Get Pack Calculation Pro')]//p[contains(text(), '$($this.CurrentState.Version -replace '(\.0+)+$')') or contains(./strong, '$($this.CurrentState.Version -replace '(\.0+)+$')')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseNotes (en-US)
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and -not ($Node.InnerText -match 'From' -and $Node.InnerText -match 'v\d+(?:\.\d+)+'); $Node = $Node.NextSibling) {
          if ($Node.InnerText -match '([a-zA-Z]+\W+\d{1,2}[a-zA-Z]+\W+20\d{2})') {
            # ReleaseTime
            $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
              $Matches[1],
              [string[]]@(
                "MMMM d'st', yyyy", "MMM d'st', yyyy",
                "MMMM d'nd', yyyy", "MMM d'nd', yyyy",
                "MMMM d'rd', yyyy", "MMM d'rd', yyyy",
                "MMMM d'th', yyyy", "MMM d'th', yyyy"
              ),
              (Get-Culture -Name 'en-US'),
              [System.Globalization.DateTimeStyles]::None
            ).ToString('yyyy-MM-dd')
          } else {
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

    # $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # # RealVersion
    # $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

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
