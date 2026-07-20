$Prefix = 'https://www.izarc.org/downloads/'
$Object1 = Invoke-RestMethod -Uri "${Prefix}update.ini" | ConvertFrom-Ini

# Version
$this.CurrentState.Version = $Object1.IZArc.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Prefix $Object1.IZArc.SetupFile
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $ReleaseNotesNode = Use-PlaywrightPage -Stealth -Headless {
        param($Page)

        $null = Open-PlaywrightPage -Page $Page -Uri 'https://www.izarc.org/news'
        Read-PlaywrightLocator -Page $Page -Selector "xpath=//article[contains(.//h2, '$($this.CurrentState.Version)')]"
      } | ConvertFrom-Html
      if ($ReleaseNotesNode) {
        # Remove unnecessary list prefixes
        $ReleaseNotesNode.SelectNodes('.//span[@class="text-primary"]').ForEach({ $_.Remove() })
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectSingleNode('.//ul') | Get-TextContent | Format-Text
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
