$Object1 = Invoke-RestMethod -Uri 'https://dwspectrum.digital-watchdog.com/api/utils/downloads'

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Join-Uri $Object1.releaseUrl $Object1.installers.Where({ $_.platform -eq 'windows_x64' -and $_.appType -eq 'server' -and $_.beta -eq $false }, 'First')[0].path
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.date | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl = $Object1.releaseNotes
      }

      $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | Read-ResponseContent -Encoding 'windows-1252' | ConvertFrom-Html

      # Replace all Wingdings characters with their Unicode equivalents
      $Object2.SelectNodes('//span[contains(@style, "font-family:Wingdings")]').ForEach({ if ($_.InnerText -match 'l|o') { $_.InnerHtml = '<span>-</span>' } })
      # Remove o:p nodes
      $Object2.SelectNodes('//*[local-name() = "o:p"]').ForEach({ $_.Remove() })
      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//div[@class='WordSection1']/*[contains(., 'DW Spectrum Release note for $($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseNotes (en-US)
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.InnerText -notmatch 'DW Spectrum Release note for '; $Node = $Node.NextSibling) {
          # Skip nodes that contain 'Password:' in their text
          if (-not $Node.InnerText.Contains('Password:')) {
            $Node
          }
        }
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
