$Prefix = 'https://github.com/CommandCodeAI/desktop/releases/latest/download/'

$Object1 = Invoke-RestMethod -Uri "${Prefix}latest.yml" | ConvertFrom-ElectronBuilderUpdateFeed

# Version
$this.CurrentState.Version = $Object1.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = Join-Uri $Prefix $Object1.Files[0].Url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.ReleaseDate | Get-Date -AsUTC
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://commandcode.ai/changelog' | ConvertFrom-Html

      $ReleaseNotesNode = $Object2.SelectSingleNode("//div[contains(@id, '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesNode) {
        # Add brackets around labels
        $ReleaseNotesNode.SelectNodes('./div[last()]//span[contains(@class, "text-brand-text")]').ForEach({ $_.InnerHtml = "[$($_.InnerText)] " })
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectNodes('./div[last()]') | Get-TextContent | Format-Text
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
