$Object1 = Invoke-RestMethod -Uri 'https://api-eu-north-1.protect.glasswire.com/api/v1.1/agent/update/check' -Body @{
  apiv       = '1'
  v          = $this.Status.Contains('New') ? '3.4.748' : $this.LastState.Version
  BUILD_TYPE = 'FULL'
  LICENSE_ID = '0'
  INSTALL_ID = ''
  PARTNER_ID = ''
  user_agent = ''
}

if ($Object1.update.status -eq 0) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

# Version
$this.CurrentState.Version = $Object1.update.version -join '.'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://download.glasswire.com/f/glasswire-setup-$($this.CurrentState.Version)-full.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.glasswire.com/changes/' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//h3[contains(text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.InnerText, '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h3'; $Node = $Node.NextSibling) {
          if (-not $Node.HasClass('download-link') -and -not $Node.HasClass('hash')) {
            $Node
          }
        }
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
